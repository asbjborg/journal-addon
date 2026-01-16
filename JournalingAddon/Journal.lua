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

-- Event schema version
local SCHEMA_VERSION = 2

-- ISO 8601 timestamp generator
local function ISOTimestamp()
  return date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Format copper amount as "Xg Ys Zc" string
local function FormatMoney(copper)
  if not copper or copper <= 0 then
    return "0c"
  end
  
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local remainingCopper = copper % 100
  
  local parts = {}
  if gold > 0 then
    table.insert(parts, gold .. "g")
  end
  if silver > 0 then
    table.insert(parts, silver .. "s")
  end
  if remainingCopper > 0 or #parts == 0 then
    table.insert(parts, remainingCopper .. "c")
  end
  
  return table.concat(parts, " ")
end

-- Simple JSON encoder for export
local function EncodeJSON(val, indent)
  indent = indent or 0
  local t = type(val)
  
  if val == nil then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    return tostring(val)
  elseif t == "string" then
    -- Escape special characters
    local escaped = val:gsub('\\', '\\\\')
      :gsub('"', '\\"')
      :gsub('\n', '\\n')
      :gsub('\r', '\\r')
      :gsub('\t', '\\t')
    return '"' .. escaped .. '"'
  elseif t == "table" then
    -- Check if array (sequential integer keys starting at 1)
    local isArray = true
    local maxIndex = 0
    for k, _ in pairs(val) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        isArray = false
        break
      end
      if k > maxIndex then
        maxIndex = k
      end
    end
    -- Also check for gaps
    if isArray and maxIndex > 0 then
      for i = 1, maxIndex do
        if val[i] == nil then
          isArray = false
          break
        end
      end
    end
    
    if isArray and maxIndex > 0 then
      -- Encode as array
      local parts = {}
      for i = 1, maxIndex do
        table.insert(parts, EncodeJSON(val[i], indent))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Encode as object
      local parts = {}
      local keys = {}
      for k in pairs(val) do
        if type(k) == "string" then
          table.insert(keys, k)
        end
      end
      table.sort(keys)
      for _, k in ipairs(keys) do
        local v = val[k]
        if v ~= nil then
          table.insert(parts, EncodeJSON(k) .. ":" .. EncodeJSON(v, indent))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  
  return "null"
end

-- Export to JSON encoder globally for UI access
Journal.EncodeJSON = EncodeJSON

-- Message renderers for each event type (derive human-readable text from structured data)
local MessageRenderers = {
  system = function(data)
    return data.message or "System event"
  end,
  
  quest = function(data)
    local suffix = data.questID and (" (" .. data.questID .. ")") or ""
    if data.action == "accepted" then
      return "Accepted: " .. (data.title or "Quest") .. suffix
    elseif data.action == "turned_in" then
      return "Turned in: " .. (data.title or "Quest") .. suffix
    end
    return "Quest: " .. (data.title or "Unknown") .. suffix
  end,
  
  activity = function(data)
    local parts = {}
    if data.target then
      -- Single target kill
      local text = "Killed: " .. data.target
      if data.count and data.count > 1 then
        text = text .. " x" .. data.count
      end
      table.insert(parts, text)
    elseif data.kills and next(data.kills) then
      local killParts = {}
      for name, count in pairs(data.kills) do
        table.insert(killParts, name .. " x" .. count)
      end
      table.sort(killParts)
      table.insert(parts, "Killed: " .. table.concat(killParts, ", "))
    end
    if data.xp and data.xp > 0 then
      table.insert(parts, "Gained " .. data.xp .. " XP")
    end
    return table.concat(parts, " | ")
  end,
  
  xp = function(data)
    return "Gained " .. (data.amount or 0) .. " XP"
  end,
  
  loot = function(data)
    if data.counts and next(data.counts) then
      local parts = {}
      for name, count in pairs(data.counts) do
        table.insert(parts, name .. " x" .. count)
      end
      table.sort(parts)
      local prefix = "Looted"
      if data.action == "create" then
        prefix = "Created"
      elseif data.action == "craft" then
        prefix = "Crafted"
      elseif data.action == "receive" then
        prefix = "Received"
      end
      return prefix .. ": " .. table.concat(parts, ", ")
    end
    return "Looted items"
  end,
  
  death = function(data)
    if data.source then
      local text = "Died to " .. data.source
      if data.spell then
        text = text .. " (" .. data.spell .. ")"
      end
      if data.level then
        text = text .. " (lvl " .. data.level .. ")"
      end
      return text
    end
    return "Died."
  end,
  
  travel = function(data)
    if data.action == "flight_start" then
      local text = "Started flying"
      if data.destination then
        text = text .. " to " .. data.destination
      end
      if data.origin then
        text = text .. " from " .. data.origin
      end
      return text .. "."
    elseif data.action == "flight_end" then
      return "Landed in " .. (data.zone or "unknown") .. "."
    elseif data.action == "hearth" then
      local toText = data.subZone and data.subZone ~= "" 
        and (data.zone .. " - " .. data.subZone) or data.zone
      local fromText = data.fromSubZone and data.fromSubZone ~= ""
        and (data.fromZone .. " - " .. data.fromSubZone) or data.fromZone
      return "Hearth to " .. (toText or "unknown") .. " from " .. (fromText or "unknown") .. "."
    else
      local toText = data.subZone and data.subZone ~= ""
        and (data.zone .. " - " .. data.subZone) or data.zone
      local fromText = data.fromSubZone and data.fromSubZone ~= ""
        and (data.fromZone .. " - " .. data.fromSubZone) or data.fromZone
      return "Traveled to " .. (toText or "unknown") .. " from " .. (fromText or "unknown") .. "."
    end
  end,
  
  reputation = function(data)
    if data.tier then
      return "Reputation tier: " .. data.tier .. " with " .. (data.faction or "Unknown")
    elseif data.amount then
      return "Reputation with " .. (data.faction or "Unknown") .. " increased by " .. data.amount
    else
      return "Reputation with " .. (data.faction or "Unknown") .. " increased"
    end
  end,
  
  level = function(data)
    return "Leveled up to " .. (data.level or "?") .. "!"
  end,
  
  screenshot = function(data)
    local action = data.action or "manual"
    
    if action == "capture_target" and data.target then
      -- Target capture: "Spotted: Name (lvl X) [reaction] screenshot=..."
      local t = data.target
      local parts = { "Spotted: " .. (t.name or "Unknown") }
      if t.level then
        table.insert(parts, "(lvl " .. t.level .. ")")
      end
      if t.reaction then
        table.insert(parts, "[" .. t.reaction .. "]")
      end
      if t.race then
        table.insert(parts, t.race)
      end
      if t.class then
        table.insert(parts, t.class)
      end
      local text = table.concat(parts, " ")
      if data.note and data.note ~= "" then
        text = text .. " note=\"" .. data.note .. "\""
      end
      if data.filename then
        text = text .. " screenshot=" .. data.filename
      end
      return text
    elseif action == "capture_scene" then
      -- Scene capture: "Scene: note=\"...\" screenshot=..."
      local text = "Scene:"
      if data.note and data.note ~= "" then
        text = text .. " note=\"" .. data.note .. "\""
      end
      if data.filename then
        text = text .. " screenshot=" .. data.filename
      end
      return text
    else
      -- Manual screenshot: "Screenshot: filename"
      return "Screenshot: " .. (data.filename or "unknown")
    end
  end,
  
  note = function(data)
    return "Note: " .. (data.text or data.note or "")
  end,
  
  money = function(data)
    return "Looted: " .. FormatMoney(data.copper or 0)
  end,
}

-- Render message from structured event data
function Journal:RenderMessage(eventType, data)
  local renderer = MessageRenderers[eventType]
  if renderer then
    return renderer(data)
  end
  -- Fallback for unknown types
  return eventType .. " event"
end

-- Create a structured event
function Journal:CreateEvent(eventType, data)
  return {
    v = SCHEMA_VERSION,
    ts = ISOTimestamp(),
    type = eventType,
    data = data,
    msg = self:RenderMessage(eventType, data),
  }
end

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
  self:MigrateDB()
end

-- Migrate old entries to new event-first schema
function Journal:MigrateDB()
  if not self.db or not self.db.sessions then
    return
  end
  
  for _, session in ipairs(self.db.sessions) do
    if session.entries then
      for _, entry in ipairs(session.entries) do
        local currentVersion = entry.v or 0
        
        -- Migrate from no version (v0) to v1
        if currentVersion < 1 then
          -- Convert Unix timestamp to ISO 8601
          if entry.ts and type(entry.ts) == "number" then
            entry.ts = date("!%Y-%m-%dT%H:%M:%SZ", entry.ts)
          end
          
          -- Move meta to data, preserve text as msg
          if entry.meta then
            entry.data = entry.meta
            entry.meta = nil
          else
            entry.data = {}
          end
          
          -- Preserve original text as msg
          if entry.text then
            entry.msg = entry.text
            entry.text = nil
          end
          
          currentVersion = 1
        end
        
        -- Migrate from v1 to v2
        if currentVersion < 2 then
          self:MigrateV1ToV2(entry)
          currentVersion = 2
        end
        
        entry.v = SCHEMA_VERSION
      end
    end
  end
end

-- Migrate v1 entries to v2 schema
function Journal:MigrateV1ToV2(entry)
  local entryType = entry.type
  local data = entry.data or {}
  
  -- Migrate target events to screenshot with capture_target action
  if entryType == "target" then
    entry.type = "screenshot"
    data.action = "capture_target"
    -- Normalize screenshot field to filename
    if data.screenshot and not data.filename then
      data.filename = data.screenshot
      data.screenshot = nil
    end
    -- Move flat target fields to nested object
    data.target = {
      name = data.name,
      level = data.level,
      reaction = data.reaction,
      race = data.race,
      class = data.class,
    }
    data.name = nil
    data.level = nil
    data.reaction = nil
    data.race = nil
    data.class = nil
  
  -- Migrate screenshot events
  elseif entryType == "screenshot" then
    -- Normalize screenshot field to filename
    if data.screenshot and not data.filename then
      data.filename = data.screenshot
      data.screenshot = nil
    end
    -- Add action if missing
    if not data.action then
      if data.note and data.note ~= "" then
        data.action = "capture_scene"
      else
        data.action = "manual"
      end
    -- Migrate old action names
    elseif data.action == "taken" then
      data.action = "manual"
    elseif data.action == "scene_note" then
      data.action = "capture_scene"
    end
  
  -- Migrate loot events
  elseif entryType == "loot" then
    if not data.action then
      -- Try to detect from raw messages
      local raw = data.raw
      if raw and type(raw) == "table" and #raw > 0 then
        local firstRaw = raw[1] or ""
        if firstRaw:match("You create:") then
          data.action = "create"
        elseif firstRaw:match("You craft:") then
          data.action = "craft"
        elseif firstRaw:match("You receive item:") then
          data.action = "receive"
        else
          data.action = "loot"
        end
      else
        data.action = "loot"
      end
    end
  
  -- Migrate activity events - convert single-target counts to target/count
  elseif entryType == "activity" then
    if data.counts and not data.target and not data.kills then
      local targetCount = 0
      local singleTarget = nil
      local singleCount = 0
      for name, count in pairs(data.counts) do
        targetCount = targetCount + 1
        singleTarget = name
        singleCount = count
      end
      if targetCount == 1 then
        data.target = singleTarget
        data.count = singleCount
        data.counts = nil
      elseif targetCount > 1 then
        data.kills = data.counts
        data.counts = nil
      end
    end
    -- Rename amount to xp for consistency
    if data.amount and not data.xp then
      data.xp = data.amount
      data.amount = nil
    end
  
  -- Migrate other event types
  elseif entryType == "quest" then
    -- Add action if missing
    if not data.action then
      local msg = entry.msg or ""
      if msg:match("^Accepted:") then
        data.action = "accepted"
      elseif msg:match("^Turned in:") then
        data.action = "turned_in"
      end
    end
  
  elseif entryType == "travel" then
    if not data.action then
      local msg = entry.msg or ""
      if msg:match("^Started flying") then
        data.action = "flight_start"
      elseif msg:match("^Landed") then
        data.action = "flight_end"
      elseif msg:match("^Hearth") then
        data.action = "hearth"
      elseif msg:match("^Flew to") then
        data.action = "zone_change"
        data.flew = true
      else
        data.action = "zone_change"
      end
    end
  
  elseif entryType == "system" then
    if not data.message then
      data.message = entry.msg or ""
    end
  
  elseif entryType == "note" then
    if not data.text then
      local msg = entry.msg or ""
      data.text = msg:gsub("^Note: ", "")
    end
  end
  
  entry.data = data
end


function Journal:InitAggregates()
  self.agg = {
    xp = { lastXP = nil, lastMaxXP = nil },
    damage = { events = {} },
  }
  self.lastZone = GetRealZoneText()
  self.lastSubZone = GetSubZoneText()
  self.inCombat = UnitAffectingCombat("player") or false
  self.inAggWindow = self.inCombat  -- Aggregation window: combat + 10s post-combat
  self.aggWindowTimer = nil
  self:ResetCombatAgg()
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
  self:AddEvent("system", { message = "Session started." })
end

function Journal:EndSession()
  if self.currentSession and not self.currentSession.endTime then
    if self.inAggWindow then
      self:CloseAggWindow()
    end
    self.currentSession.endTime = time()
  end
end

-- New event-first entry creation
function Journal:AddEvent(eventType, data)
  if not self.currentSession then
    return
  end
  local event = self:CreateEvent(eventType, data)
  table.insert(self.currentSession.entries, event)
  if self.debug then
    self:DebugLog("Event added: " .. eventType .. " - " .. event.msg)
  end
  if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
    self:RefreshUI()
  end
end

-- Legacy wrapper for backwards compatibility during transition
function Journal:AddEntry(entryType, text, meta)
  if not self.currentSession then
    return
  end
  -- Convert to new event format
  local data = meta or {}
  local event = {
    v = SCHEMA_VERSION,
    ts = ISOTimestamp(),
    type = entryType,
    data = data,
    msg = text,
  }
  table.insert(self.currentSession.entries, event)
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
    loot = { counts = {}, raw = {}, action = nil },
    money = 0,
  }
end

function Journal:StartAggWindowTimer()
  -- Cancel existing timer if any
  if self.aggWindowTimer then
    self.aggWindowTimer:Cancel()
    self.aggWindowTimer = nil
  end
  
  -- Keep aggregation window open
  self.inAggWindow = true
  
  -- Start 10-second timer to flush
  if C_Timer and C_Timer.NewTimer then
    self.aggWindowTimer = C_Timer.NewTimer(LOOT_MERGE_WINDOW, function()
      Journal:CloseAggWindow()
    end)
  else
    -- Fallback: flush immediately if no timer available
    self:CloseAggWindow()
  end
end

function Journal:CloseAggWindow()
  if self.aggWindowTimer then
    self.aggWindowTimer:Cancel()
    self.aggWindowTimer = nil
  end
  self.inAggWindow = false
  self:FlushCombatAgg()
end

function Journal:FlushCombatAgg()
  if not self.currentSession or not self.combatAgg then
    return
  end

  local killCounts = self.combatAgg.kills
  local xpTotal = self.combatAgg.xp
  if next(killCounts) or xpTotal > 0 then
    -- Count unique targets
    local targetCount = 0
    local singleTarget = nil
    local singleCount = 0
    for name, count in pairs(killCounts) do
      targetCount = targetCount + 1
      singleTarget = name
      singleCount = count
    end
    
    local eventData = {
      xp = xpTotal > 0 and xpTotal or nil,
    }
    
    if targetCount == 1 then
      -- Single target type - use cleaner format
      eventData.target = singleTarget
      eventData.count = singleCount
    elseif targetCount > 1 then
      -- Multiple targets - use kills map
      eventData.kills = CopyTable(killCounts)
    end
    
    self:AddEvent("activity", eventData)
  end

  local lootCounts = self.combatAgg.loot.counts
  if next(lootCounts) then
    self:AddEvent("loot", {
      action = self.combatAgg.loot.action or "loot",
      counts = CopyTable(lootCounts),
      raw = CopyTable(self.combatAgg.loot.raw),
    })
  end

  local money = self.combatAgg.money
  if money and money > 0 then
    self:AddEvent("money", { copper = money })
  end

  self:ResetCombatAgg()
end

function Journal:RecordKill(destName)
  if not destName or destName == "" then
    return
  end
  
  if self.inAggWindow then
    local counts = self.combatAgg.kills
    counts[destName] = (counts[destName] or 0) + 1
  else
    -- Kill outside aggregation window - log immediately
    self:AddEvent("activity", { target = destName, count = 1 })
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
    if self.inAggWindow then
      self.combatAgg.xp = self.combatAgg.xp + delta
    else
      self:AddEvent("xp", { amount = delta })
    end
  end

  self.agg.xp.lastXP = currentXP
  self.agg.xp.lastMaxXP = currentMax
end

function Journal:DetectLootAction(msg)
  if msg:match("You create:") then
    return "create"
  elseif msg:match("You craft:") then
    return "craft"
  elseif msg:match("You receive item:") then
    return "receive"
  else
    return "loot"
  end
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
    itemName = msg:match("You create: (.+)")
  end
  if not itemName then
    itemName = msg:match("You craft: (.+)")
  end
  if not itemName then
    return
  end
  
  -- Clean item name (remove quantity suffix if present)
  itemName = itemName:gsub("x%d+$", ""):gsub("%s+$", "")

  local action = self:DetectLootAction(msg)
  local count = tonumber(msg:match("x(%d+)")) or 1
  
  if self.inAggWindow then
    -- Add to aggregation window
    local counts = self.combatAgg.loot.counts
    counts[itemName] = (counts[itemName] or 0) + count
    table.insert(self.combatAgg.loot.raw, msg)
    -- Store action for loot (use first seen action)
    if not self.combatAgg.loot.action then
      self.combatAgg.loot.action = action
    end
    -- Extend the timer if we're in post-combat window
    if not self.inCombat and self.aggWindowTimer then
      self:StartAggWindowTimer()
    end
  else
    -- Not in aggregation window - log immediately
    self:AddEvent("loot", {
      action = action,
      counts = { [itemName] = count },
      raw = { msg },
    })
  end
end

function Journal:ParseMoneyFromMessage(msg)
  if not msg then
    return 0
  end
  
  local copper = 0
  
  -- Parse gold, silver, copper from message
  -- Patterns: "You loot X Gold", "You loot X Silver", "You loot X Copper"
  -- Also handles combined: "You loot X Gold, Y Silver, Z Copper"
  local gold = msg:match("(%d+) Gold")
  local silver = msg:match("(%d+) Silver")
  local copperMatch = msg:match("(%d+) Copper")
  
  if gold then
    copper = copper + (tonumber(gold) * 10000)
  end
  if silver then
    copper = copper + (tonumber(silver) * 100)
  end
  if copperMatch then
    copper = copper + tonumber(copperMatch)
  end
  
  return copper
end

function Journal:RecordMoney(msg)
  if not msg or msg == "" then
    return
  end
  
  local copper = self:ParseMoneyFromMessage(msg)
  if copper <= 0 then
    return
  end
  
  if self.inAggWindow then
    -- Add to aggregation window
    self.combatAgg.money = self.combatAgg.money + copper
    -- Extend the timer if we're in post-combat window
    if not self.inCombat and self.aggWindowTimer then
      self:StartAggWindowTimer()
    end
  else
    -- Not in aggregation window - log immediately
    self:AddEvent("money", { copper = copper })
  end
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
    local level = self:GetSourceLevel(last.source)
    self:AddEvent("death", {
      source = last.source,
      spell = last.spell,
      level = level,
    })
  else
    self:AddEvent("death", {})
  end
  self.agg.damage.events = {}
end

function Journal:LogQuestAccepted(questLogIndex, questID)
  local title, _, _, _, _, _, _, derivedQuestID = GetQuestLogTitle(questLogIndex)
  questID = questID or derivedQuestID
  if not title or title == "" then
    title = questID and ("Quest " .. questID) or "Quest"
  end
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  self:AddEvent("quest", {
    action = "accepted",
    questID = questID,
    title = title,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
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
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  self:AddEvent("quest", {
    action = "turned_in",
    questID = questID,
    title = title,
    xp = xpReward,
    money = moneyReward,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
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
  self:AddEvent("travel", {
    action = "flight_start",
    origin = origin,
    destination = dest,
    hops = self.flightState.hops,
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
  local subZone = GetSubZoneText()
  self:AddEvent("travel", {
    action = "flight_end",
    zone = zone,
    subZone = subZone,
  })
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
      local isHearth = self.lastHearthCastAt and (time() - self.lastHearthCastAt) <= 90

      self:AddEvent("travel", {
        action = isHearth and "hearth" or "zone_change",
        zone = zone,
        subZone = subZone,
        fromZone = fromZone,
        fromSubZone = fromSub,
      })

      if isHearth then
        self.lastHearthCastAt = nil
        self.lastHearthFrom = nil
      end
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

function Journal:HandleReputationChange(msg)
  local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  
  local faction, amount = cleaned:match("Your reputation with (.+) has increased by (%d+)")
  if faction and amount then
    amount = tonumber(amount)
    self:AddEvent("reputation", {
      faction = faction,
      amount = amount,
    })
    return
  end
  
  faction = cleaned:match("Your reputation with (.+) has .* increased")
  if faction then
    self:AddEvent("reputation", {
      faction = faction,
    })
  end
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

function Journal:CaptureTarget(note)
  local screenshotName = self.pendingScreenshotName
  self.pendingScreenshotName = nil
  local hasTarget = self.pendingHasTarget
  self.pendingHasTarget = nil
  
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()

  if hasTarget and UnitExists("target") then
    local name = UnitName("target")
    if name and name ~= "" then
      local level = UnitLevel("target")
      if level and level <= 0 then
        level = nil
      end

      local reaction = UnitReaction("player", "target")
      local reactionText = nil
      if reaction then
        if reaction >= 5 then
          reactionText = "friendly"
        elseif reaction >= 4 then
          reactionText = "neutral"
        else
          reactionText = "hostile"
        end
      end

      local race = UnitRace("target")
      local class = UnitClass("target")

      -- Target capture - all in one screenshot event
      self:AddEvent("screenshot", {
        action = "capture_target",
        filename = screenshotName,
        note = (note and note ~= "") and note or nil,
        zone = zone,
        subZone = (subZone and subZone ~= "") and subZone or nil,
        target = {
          name = name,
          level = level,
          reaction = reactionText,
          race = (race and race ~= "") and race or nil,
          class = (class and class ~= "") and class or nil,
        },
      })
      return
    end
  end

  -- Scene capture (no target)
  self:AddEvent("screenshot", {
    action = "capture_scene",
    filename = screenshotName,
    note = (note and note ~= "") and note or nil,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
end

function Journal:ShowTargetCaptureDialog()
  self.pendingScreenshotName = self:GetScreenshotName()
  self.pendingHasTarget = UnitExists("target")
  
  if Screenshot then
    Screenshot()
  end

  local function ShowDialog()
    if not Journal.targetCaptureFrame then
      Journal:CreateTargetCaptureDialog()
    end
    if Journal.targetCaptureFrame then
      Journal.targetCaptureFrame:Show()
      Journal.targetCaptureFrame:Raise()
      Journal.targetCaptureFrame.editBox:SetText("")
      Journal.targetCaptureFrame.editBox:SetFocus()
    end
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(2.5, ShowDialog)
  else
    ShowDialog()
  end
end

function Journal:CreateTargetCaptureDialog()
  if self.targetCaptureFrame then
    return
  end

  local frame = CreateFrame("Frame", "JournalTargetCaptureFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(400, 120)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Capture - Add Note")

  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  label:SetText("Note (optional):")

  local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  editBox:SetSize(360, 32)
  editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  editBox:SetAutoFocus(true)
  editBox:SetScript("OnEnterPressed", function(self)
    local note = self:GetText()
    Journal:CaptureTarget(note)
    frame:Hide()
  end)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  frame.editBox = editBox

  local captureButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  captureButton:SetSize(100, 22)
  captureButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
  captureButton:SetText("Capture")
  captureButton:SetScript("OnClick", function()
    local note = editBox:GetText()
    Journal:CaptureTarget(note)
    frame:Hide()
  end)

  local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  cancelButton:SetSize(100, 22)
  cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
  cancelButton:SetText("Cancel")
  cancelButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  self.targetCaptureFrame = frame
end

function Journal:CaptureNote(note)
  if not note or note == "" then
    return
  end
  
  self:AddEvent("note", {
    text = note,
  })
end

function Journal:ShowNoteCaptureDialog()
  if not self.noteCaptureFrame then
    self:CreateNoteCaptureDialog()
  end
  if self.noteCaptureFrame then
    self.noteCaptureFrame:Show()
    self.noteCaptureFrame:Raise()
    self.noteCaptureFrame.editBox:SetText("")
    self.noteCaptureFrame.editBox:SetFocus()
  end
end

function Journal:CreateNoteCaptureDialog()
  if self.noteCaptureFrame then
    return
  end

  local frame = CreateFrame("Frame", "JournalNoteCaptureFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(500, 300)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Add Note")

  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  label:SetText("Note:")

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 50)

  local editBox = CreateFrame("EditBox", nil, scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetWidth(scrollFrame:GetWidth() - 20)
  editBox:SetAutoFocus(true)
  editBox:EnableMouse(true)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  scrollFrame:SetScrollChild(editBox)
  frame.editBox = editBox

  local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  saveButton:SetSize(100, 22)
  saveButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
  saveButton:SetText("Save")
  saveButton:SetScript("OnClick", function()
    local note = editBox:GetText()
    if note and note ~= "" then
      Journal:CaptureNote(note)
    end
    frame:Hide()
  end)

  local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  cancelButton:SetSize(100, 22)
  cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
  cancelButton:SetText("Cancel")
  cancelButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  self.noteCaptureFrame = frame
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
    if self.inAggWindow then
      self:CloseAggWindow()
    end
  elseif event == "QUEST_TURNED_IN" then
    local questID, xpReward, moneyReward = ...
    if questID then
      self:LogQuestTurnedIn(questID, xpReward, moneyReward)
    end
    if self.inAggWindow then
      self:CloseAggWindow()
    end
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
      local repTier = cleaned:match("^You are now (.+) with (.+)%.$")
      if repTier then
        local tier, faction = repTier:match("^(.+) with (.+)$")
        if tier and faction then
          self:AddEvent("reputation", {
            faction = faction,
            tier = tier,
          })
        end
      end
    end
  elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    local msg = ...
    if msg and msg ~= "" then
      self:HandleReputationChange(msg)
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
    -- Don't flush yet - start 10-second post-combat window for looting
    self:StartAggWindowTimer()
  elseif event == "CHAT_MSG_MONEY" then
    local msg = ...
    self:RecordMoney(msg)
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Flush previous aggregation window before starting new combat
    if self.inAggWindow then
      self:CloseAggWindow()
    end
    self.inCombat = true
    self.inAggWindow = true  -- Start new aggregation window
  elseif event == "PLAYER_LEVEL_UP" then
    local level = ...
    self:AddEvent("level", { level = level })
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
    -- Skip if we're in a pending capture (will be handled by CaptureTarget)
    if self.pendingScreenshotName then
      return
    end
    local screenshotName = self:GetScreenshotName()
    local zone = GetRealZoneText()
    local subZone = GetSubZoneText()
    self:AddEvent("screenshot", {
      action = "manual",
      filename = screenshotName,
      zone = zone,
      subZone = (subZone and subZone ~= "") and subZone or nil,
    })
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
frame:RegisterEvent("CHAT_MSG_MONEY")
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
frame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
