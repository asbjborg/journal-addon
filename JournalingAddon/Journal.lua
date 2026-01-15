local addonName, Journal = ...
Journal = Journal or {}
Journal.addonName = addonName
_G.Journal = Journal

local frame = CreateFrame("Frame")
Journal.frame = frame

local DAMAGE_WINDOW = 10
local TAXI_WINDOW = 120
local LOOT_MERGE_WINDOW = 10
Journal.debug = false

local function CopyTable(src)
  local dst = {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      local child = {}
      for ck, cv in pairs(v) do
        child[ck] = cv
      end
      dst[k] = child
    else
      dst[k] = v
    end
  end
  return dst
end

local function BuildCountText(counts)
  local parts = {}
  for name, count in pairs(counts) do
    table.insert(parts, name .. " x" .. count)
  end
  table.sort(parts)
  return table.concat(parts, ", ")
end

function Journal:InitDB()
  if not JournalDB then
    JournalDB = {}
  end
  if not JournalDB.sessions then
    JournalDB.sessions = {}
  end
  self.db = JournalDB
end

function Journal:InitAggregates()
  self.agg = {
    xp = { lastXP = nil, lastMaxXP = nil },
    damage = { events = {} },
  }
  self.lastZone = GetRealZoneText()
  self.lastSubZone = GetSubZoneText()
  self.inCombat = UnitAffectingCombat("player") or false
  self:ResetCombatAgg()
  self.pendingLoot = {}
  self.lastQuestCompleted = nil
  self.lastHearthCastAt = nil
  self.lastHearthFrom = nil
  self.flightState = {
    onTaxi = false,
    originZone = nil,
    originName = nil,
    destinationName = nil,
    destinationZone = nil,
    startedAt = nil,
    hops = nil,
  }
end

function Journal:GetCharacterKey()
  local name = UnitName("player")
  local realm = GetRealmName()
  if name and realm and realm ~= "" then
    return name .. "-" .. realm
  end
  return name or "Unknown"
end

function Journal:GetDayKey()
  return date("%Y-%m-%d")
end

function Journal:FindSessionForDay(characterKey, dayKey)
  for i = #self.db.sessions, 1, -1 do
    local session = self.db.sessions[i]
    if session.characterKey == characterKey and session.dayKey == dayKey then
      return session
    end
  end
  return nil
end

function Journal:StartSession()
  local characterKey = self:GetCharacterKey()
  local dayKey = self:GetDayKey()
  local session = self:FindSessionForDay(characterKey, dayKey)

  if session then
    session.endTime = nil
    session.entries = session.entries or {}
    self.currentSession = session
    return
  end

  session = {
    startTime = time(),
    endTime = nil,
    entries = {},
    characterKey = characterKey,
    dayKey = dayKey,
  }
  table.insert(self.db.sessions, session)
  self.currentSession = session
  self:AddEntry("system", "Session started.", nil)
end

function Journal:EndSession()
  if self.currentSession and not self.currentSession.endTime then
    self:FlushCombatAgg()
    self:FlushPendingLoot()
    self.currentSession.endTime = time()
  end
end

function Journal:AddEntry(entryType, text, meta)
  if not self.currentSession then
    return
  end
  local entry = {
    ts = time(),
    type = entryType,
    text = text,
    meta = meta,
  }
  table.insert(self.currentSession.entries, entry)
  if self.debug then
    self:DebugLog("Entry added: " .. entryType .. " - " .. text)
  end
  if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
    self:RefreshUI()
  end
end

function Journal:ResetCombatAgg()
  self.combatAgg = {
    kills = {},
    xp = 0,
    loot = { counts = {}, raw = {} },
  }
end

function Journal:FlushCombatAgg()
  if not self.currentSession or not self.combatAgg then
    return
  end

  local killCounts = self.combatAgg.kills
  local xpTotal = self.combatAgg.xp
  if next(killCounts) or xpTotal > 0 then
    local parts = {}
    local meta = {}
    if next(killCounts) then
      table.insert(parts, "Killed: " .. BuildCountText(killCounts))
      meta.counts = CopyTable(killCounts)
    end
    if xpTotal > 0 then
      table.insert(parts, "Gained " .. xpTotal .. " XP")
      meta.amount = xpTotal
    end
    self:AddEntry("activity", table.concat(parts, " | "), meta)
  end

  local lootCounts = self.combatAgg.loot.counts
  if next(lootCounts) then
    local text = BuildCountText(lootCounts)
    self:AddEntry("loot", "Looted: " .. text, {
      counts = CopyTable(lootCounts),
      raw = CopyTable(self.combatAgg.loot.raw),
    })
  end

  self:ResetCombatAgg()
end

function Journal:RecordKill(destName)
  if not destName or destName == "" then
    return
  end
  local counts = self.combatAgg.kills
  counts[destName] = (counts[destName] or 0) + 1
  if not self.inCombat then
    self:FlushCombatAgg()
  end
end

function Journal:RecordXP()
  local currentXP = UnitXP("player")
  local currentMax = UnitXPMax("player")
  if not self.agg.xp.lastXP then
    self.agg.xp.lastXP = currentXP
    self.agg.xp.lastMaxXP = currentMax
    return
  end

  local delta = currentXP - self.agg.xp.lastXP
  if delta < 0 and self.agg.xp.lastMaxXP then
    delta = (self.agg.xp.lastMaxXP - self.agg.xp.lastXP) + currentXP
  end

  if delta > 0 then
    if self.inCombat then
      self.combatAgg.xp = self.combatAgg.xp + delta
    else
      self:AddEntry("xp", "Gained " .. delta .. " XP", { amount = delta })
    end
  end

  self.agg.xp.lastXP = currentXP
  self.agg.xp.lastMaxXP = currentMax
end

function Journal:RecordLoot(msg)
  if not msg or msg == "" then
    return
  end
  local itemLink = msg:match("|Hitem:.-|h%[.-%]|h")
  local itemName = nil
  if itemLink then
    itemName = itemLink:match("%[(.-)%]")
  end
  if not itemName then
    itemName = msg:match("You receive loot: (.+)")
  end
  if not itemName then
    itemName = msg:match("You receive item: (.+)")
  end
  if not itemName then
    return
  end

  local count = tonumber(msg:match("x(%d+)")) or 1
  if self.inCombat then
    local counts = self.combatAgg.loot.counts
    counts[itemName] = (counts[itemName] or 0) + count
    table.insert(self.combatAgg.loot.raw, msg)
  else
    local now = time()
    local pending = self.pendingLoot[itemName]
    if pending and (now - pending.lastTs) <= LOOT_MERGE_WINDOW then
      pending.count = pending.count + count
      table.insert(pending.raw, msg)
      pending.lastTs = now
    else
      if pending then
        self:FlushPendingLoot(itemName)
      end
      pending = {
        count = count,
        raw = { msg },
        lastTs = now,
        timer = nil,
      }
      self.pendingLoot[itemName] = pending
    end

    if C_Timer and C_Timer.NewTimer then
      if pending.timer then
        pending.timer:Cancel()
      end
      pending.timer = C_Timer.NewTimer(LOOT_MERGE_WINDOW, function()
        self:FlushPendingLoot(itemName)
      end)
    end
  end
end

function Journal:FlushPendingLoot(itemName)
  if not self.pendingLoot then
    return
  end
  if itemName then
    local pending = self.pendingLoot[itemName]
    if not pending then
      return
    end
    if pending.timer then
      pending.timer:Cancel()
    end
    self:AddEntry("loot", "Looted: " .. itemName .. " x" .. pending.count, {
      counts = { [itemName] = pending.count },
      raw = CopyTable(pending.raw),
    })
    self.pendingLoot[itemName] = nil
    return
  end

  for name, pending in pairs(self.pendingLoot) do
    if pending.timer then
      pending.timer:Cancel()
    end
    self:AddEntry("loot", "Looted: " .. name .. " x" .. pending.count, {
      counts = { [name] = pending.count },
      raw = CopyTable(pending.raw),
    })
  end
  self.pendingLoot = {}
end

function Journal:RecordDamage(eventTime, sourceName, spellName, amount)
  local events = self.agg.damage.events
  table.insert(events, {
    ts = eventTime,
    source = sourceName or "Unknown",
    spell = spellName,
    amount = amount,
  })
  self:PruneDamage(eventTime)
end

function Journal:PruneDamage(now)
  local events = self.agg.damage.events
  local cutoff = now - DAMAGE_WINDOW
  while #events > 0 and events[1].ts < cutoff do
    table.remove(events, 1)
  end
end

function Journal:GetSourceLevel(sourceName)
  if UnitExists("target") and UnitName("target") == sourceName then
    local level = UnitLevel("target")
    if level and level > 0 then
      return level
    end
  end
  return nil
end

function Journal:RecordDeath()
  self:PruneDamage(GetTime())
  local events = self.agg.damage.events
  local last = events[#events]
  if last then
    local text = "Died to " .. last.source
    if last.spell then
      text = text .. " (" .. last.spell .. ")"
    end
    local level = self:GetSourceLevel(last.source)
    if level then
      text = text .. " (lvl " .. level .. ")"
    end
    self:AddEntry("death", text, { source = last.source, spell = last.spell })
  else
    self:AddEntry("death", "Died.", nil)
  end
  self.agg.damage.events = {}
end

function Journal:LogQuestAccepted(questLogIndex, questID)
  local title, _, _, _, _, _, _, derivedQuestID = GetQuestLogTitle(questLogIndex)
  questID = questID or derivedQuestID
  if not title or title == "" then
    title = questID and ("Quest " .. questID) or "Quest"
  end
  local suffix = questID and (" (" .. questID .. ")") or ""
  self:AddEntry("quest", "Accepted: " .. title .. suffix, {
    questID = questID,
    title = title,
  })
  if title and title ~= "" then
    -- no-op; kept for future filtering if needed
  end
end

function Journal:LogQuestTurnedIn(questID, xpReward, moneyReward)
  local title = nil
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    title = C_QuestLog.GetTitleForQuestID(questID)
  end
  local fallbackTitle = nil
  if self.lastQuestCompleted and (time() - self.lastQuestCompleted.ts) <= 5 then
    fallbackTitle = self.lastQuestCompleted.title
  end
  if not title or title == "" or title == ("Quest " .. questID) then
    title = fallbackTitle or ("Quest " .. questID)
  end
  local suffix = questID and (" (" .. questID .. ")") or ""
  self:AddEntry("quest", "Turned in: " .. title .. suffix, {
    questID = questID,
    title = title,
    xp = xpReward,
    money = moneyReward,
  })
  self.lastQuestCompleted = nil
end

function Journal:DebugLog(message)
  if not self.debug then
    return
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r " .. message)
  end
end

function Journal:HandleFlightStart()
  if self.flightState.onTaxi then
    return
  end
  self.flightState.onTaxi = true
  if not self.flightState.originZone then
    self.flightState.originZone = GetRealZoneText()
  end
  self.flightState.startedAt = time()
  local dest = self.flightState.destinationName
  local origin = self.flightState.originName or self.flightState.originZone
  local text = "Started flying"
  if dest then
    text = text .. " to " .. dest
  end
  if origin then
    text = text .. " from " .. origin
  end
  self:AddEntry("travel", text .. ".", {
    origin = origin,
    destination = dest,
  })
end

function Journal:CaptureTaxiOrigin()
  if not NumTaxiNodes then
    return
  end
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then
      local nodeName = TaxiNodeName(i)
      if nodeName and nodeName ~= "" then
        local location, zone = nodeName:match("^([^,]+),?%s*(.*)$")
        self.flightState.originName = location or nodeName
        if zone and zone ~= "" then
          self.flightState.originZone = zone
        end
      end
      return
    end
  end
end

function Journal:CaptureTaxiDestination(index)
  if not index or index <= 0 then
    return
  end
  local nodeName = TaxiNodeName(index)
  if not nodeName or nodeName == "" then
    return
  end
  local location, zone = nodeName:match("^([^,]+),?%s*(.*)$")
  location = location or nodeName
  self.flightState.destinationName = location
  self.flightState.destinationZone = zone
  if GetNumRoutes and GetNumRoutes(index) and GetNumRoutes(index) > 0 then
    local hops = {}
    for routeIndex = 1, GetNumRoutes(index) do
      local sourceSlot = TaxiGetNodeSlot(index, routeIndex, true)
      local destSlot = TaxiGetNodeSlot(index, routeIndex, false)
      if sourceSlot and destSlot then
        local sourceName = TaxiNodeName(sourceSlot)
        local destName = TaxiNodeName(destSlot)
        if sourceName and destName then
          local srcLoc = sourceName:match("^([^,]+)")
          local dstLoc = destName:match("^([^,]+)")
          table.insert(hops, { from = srcLoc or sourceName, to = dstLoc or destName })
        end
      end
    end
    if #hops > 0 then
      self.flightState.hops = hops
    end
  end
end

function Journal:HandleFlightEnd()
  if not self.flightState.onTaxi then
    return
  end
  self.flightState.onTaxi = false
  local zone = GetRealZoneText()
  local text = "Landed in " .. zone
  self:AddEntry("travel", text .. ".", { zone = zone })
  self.flightState.originZone = nil
  self.flightState.destinationName = nil
  self.flightState.destinationZone = nil
  self.flightState.originName = nil
  self.flightState.startedAt = nil
  self.flightState.hops = nil
end

function Journal:HandleZoneChanged()
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  if not zone or zone == "" then
    return
  end
  
  if self.lastZone and zone ~= self.lastZone then
    if not self.flightState.onTaxi then
      local fromZone = self.lastZone
      local fromSub = self.lastSubZone
      local toZone = zone
      local toSub = subZone
      local toText = toSub and toSub ~= "" and (toZone .. " - " .. toSub) or toZone
      local fromText = fromSub and fromSub ~= "" and (fromZone .. " - " .. fromSub) or fromZone
      local text = "Traveled to " .. toText .. " from " .. fromText

      if self.lastHearthCastAt and (time() - self.lastHearthCastAt) <= 90 then
        text = "Hearth to " .. toText .. " from " .. (self.lastHearthFrom or fromText)
        self.lastHearthCastAt = nil
        self.lastHearthFrom = nil
      end

      self:AddEntry("travel", text .. ".", {
        zone = toZone,
        subZone = toSub,
        fromZone = fromZone,
        fromSubZone = fromSub,
      })
    end
  end
  
  if not self.lastZone or zone ~= self.lastZone then
    self.lastZone = zone
  end
  self.lastSubZone = subZone
end

function Journal:DetectTravelType()
  return nil
end

function Journal:GetScreenshotName()
  local now = date("*t")
  local month = string.format("%02d", now.month)
  local day = string.format("%02d", now.day)
  local year = string.format("%02d", now.year % 100)
  local hour = string.format("%02d", now.hour)
  local min = string.format("%02d", now.min)
  local sec = string.format("%02d", now.sec)
  return "WoWScrnShot_" .. month .. day .. year .. "_" .. hour .. min .. sec .. ".jpg"
end

function Journal:OnCombatLog()
  local timestamp, subevent, _, _, srcName, _, _, destGUID, destName, destFlags, _, _, spellName, _, amount =
    CombatLogGetCurrentEventInfo()

  if subevent == "PARTY_KILL" then
    if destFlags and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0 then
      self:RecordKill(destName)
    end
    return
  end

  if destGUID == UnitGUID("player") then
    if subevent == "SWING_DAMAGE" then
      self:RecordDamage(timestamp, srcName, "Melee", amount)
    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
      self:RecordDamage(timestamp, srcName, spellName, amount)
    end
  end
end

function Journal:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    self:InitDB()
    self:InitAggregates()
    self:StartSession()
    self.agg.xp.lastXP = UnitXP("player")
    self.agg.xp.lastMaxXP = UnitXPMax("player")
    if self.InitUI then
      self:InitUI()
    end
  elseif event == "PLAYER_LOGOUT" then
    self:EndSession()
  elseif event == "QUEST_ACCEPTED" then
    local questLogIndex, questID = ...
    if questLogIndex then
      self:LogQuestAccepted(questLogIndex, questID)
    end
    self:FlushPendingLoot()
  elseif event == "QUEST_TURNED_IN" then
    local questID, xpReward, moneyReward = ...
    if questID then
      self:LogQuestTurnedIn(questID, xpReward, moneyReward)
    end
    self:FlushPendingLoot()
  elseif event == "CHAT_MSG_SYSTEM" then
    local msg = ...
    if msg and msg ~= "" then
      local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      local name = cleaned:match("^Quest completed: (.+)$")
        or cleaned:match("^(.+) completed%.$")
      if name and name ~= "" then
        self.lastQuestCompleted = { title = name, ts = time() }
      end
      local flightDest = cleaned:match("^Taking flight to: %[(.+)%]$")
      if flightDest and flightDest ~= "" then
        self.flightState.destinationName = flightDest
        if not self.flightState.onTaxi then
          self:HandleFlightStart()
        end
      end
    end
  elseif event == "PLAYER_XP_UPDATE" then
    self:RecordXP()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    self:OnCombatLog()
  elseif event == "CHAT_MSG_LOOT" then
    local msg = ...
    self:RecordLoot(msg)
  elseif event == "PLAYER_CONTROL_LOST" then
    if UnitOnTaxi("player") and not self.flightState.onTaxi then
      if not self.flightState.originName then
        self:CaptureTaxiOrigin()
      end
      if not self.flightState.destinationName then
        self.flightState.originZone = GetRealZoneText()
      end
      self:HandleFlightStart()
    end
  elseif event == "PLAYER_CONTROL_GAINED" then
    if self.flightState.onTaxi then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
          if Journal.flightState.onTaxi and not UnitOnTaxi("player") then
            Journal:HandleFlightEnd()
          end
        end)
      else
        if not UnitOnTaxi("player") then
          self:HandleFlightEnd()
        end
      end
    end
    -- no-op for transports
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    if self.flightState.onTaxi and not UnitOnTaxi("player") then
      self:HandleFlightEnd()
    end
    self:HandleZoneChanged()
  elseif event == "PLAYER_DEAD" then
    self:RecordDeath()
  elseif event == "PLAYER_REGEN_ENABLED" then
    self.inCombat = false
    self:FlushCombatAgg()
  elseif event == "PLAYER_REGEN_DISABLED" then
    self.inCombat = true
    self:FlushPendingLoot()
  elseif event == "PLAYER_LEVEL_UP" then
    local level = ...
    self:AddEntry("level", "Leveled up to " .. level .. "!", { level = level })
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, spellName = ...
    if unit == "player" and spellName then
      local hearthNames = {
        "Hearthstone",
        "Innkeeper's Daughter",
        "Astral Recall",
        "Home",
      }
      for _, name in ipairs(hearthNames) do
        if spellName:find(name, 1, true) then
          self.lastHearthCastAt = time()
          local zone = GetRealZoneText()
          local subZone = GetSubZoneText()
          self.lastHearthFrom = (subZone and subZone ~= "" and (zone .. " - " .. subZone)) or zone
          break
        end
      end
    end
  elseif event == "SCREENSHOT_SUCCEEDED" then
    local screenshotName = self:GetScreenshotName()
    self:AddEntry("screenshot", "Screenshot: " .. screenshotName, { filename = screenshotName })
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  Journal:OnEvent(event, ...)
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

hooksecurefunc("TakeTaxiNode", function(index)
  if not Journal.flightState.onTaxi then
    Journal:CaptureTaxiOrigin()
    Journal:CaptureTaxiDestination(index)
    Journal:HandleFlightStart()
  end
end)
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("SCREENSHOT_SUCCEEDED")
