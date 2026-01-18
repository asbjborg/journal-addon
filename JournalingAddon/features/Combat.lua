local _, Journal = ...
Journal = Journal or _G.Journal or {}

local DAMAGE_WINDOW = 10
local LOOT_MERGE_WINDOW = 10
local LOOT_AGG_WINDOW = 180  -- 3 minutes for loot aggregation

function Journal:ResetCombatAgg()
  self.combatAgg = {
    kills = {},
    xp = 0,
    loot = { counts = {}, raw = {}, action = nil },
    money = 0,
    reputation = {},  -- { [faction] = change }
  }
end

function Journal:ResetLootAgg()
  self.lootAgg = {
    counts = {},
    raw = {},
    action = nil,
    startTime = nil,
  }
end

function Journal:StartLootAggWindow()
  -- Initialize loot aggregation if not already started
  if not self.lootAgg then
    self:ResetLootAgg()
  end
  
  -- Set start time if not already set
  if not self.lootAgg.startTime then
    self.lootAgg.startTime = time()
  end
  
  -- Cancel existing timer if any
  if self.lootAggTimer then
    self.lootAggTimer:Cancel()
    self.lootAggTimer = nil
  end
  
  -- Start 3-minute timer to flush
  if C_Timer and C_Timer.NewTimer then
    self.lootAggTimer = C_Timer.NewTimer(LOOT_AGG_WINDOW, function()
      Journal:CloseLootAggWindow()
    end)
  else
    -- Fallback: flush immediately if no timer available
    self:CloseLootAggWindow()
  end
end

function Journal:CloseLootAggWindow()
  if self.lootAggTimer then
    self.lootAggTimer:Cancel()
    self.lootAggTimer = nil
  end
  
  if self.lootAgg and self.lootAgg.startTime and next(self.lootAgg.counts) then
    local duration = time() - self.lootAgg.startTime
    local minutes = math.floor(duration / 60)
    local seconds = duration % 60
    
    -- Format duration: "Xm" if >= 60s, otherwise "Xs"
    local durationText = minutes > 0 and (minutes .. "m") or (seconds .. "s")
    
    self:AddEvent("loot", {
      action = self.lootAgg.action or "loot",
      counts = Journal.CopyTable(self.lootAgg.counts),
      raw = Journal.CopyTable(self.lootAgg.raw),
      duration = duration,
      durationText = durationText,
    })
  end
  
  self:ResetLootAgg()
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
      eventData.kills = Journal.CopyTable(killCounts)
    end

    self:AddEvent("activity", eventData)
  end

  local lootCounts = self.combatAgg.loot.counts
  if next(lootCounts) then
    self:AddEvent("loot", {
      action = self.combatAgg.loot.action or "loot",
      counts = Journal.CopyTable(lootCounts),
      raw = Journal.CopyTable(self.combatAgg.loot.raw),
    })
  end

  local money = self.combatAgg.money
  if money and money > 0 then
    self:AddEvent("money", { copper = money })
  end

  local reputation = self.combatAgg.reputation
  if reputation and next(reputation) then
    self:AddEvent("reputation", {
      changes = Journal.CopyTable(reputation),
    })
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
    -- Add to combat aggregation window (during/after combat)
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
    -- Not in combat aggregation - check if we should use loot aggregation window
    -- Start loot aggregation window if not already active
    if not self.lootAgg or not self.lootAgg.startTime then
      self:StartLootAggWindow()
    end
    
    -- Add to loot aggregation
    local counts = self.lootAgg.counts
    counts[itemName] = (counts[itemName] or 0) + count
    table.insert(self.lootAgg.raw, msg)
    -- Store action for loot (use first seen action)
    if not self.lootAgg.action then
      self.lootAgg.action = action
    end
    
    -- Extend the timer
    if self.lootAggTimer then
      self.lootAggTimer:Cancel()
      self.lootAggTimer = nil
    end
    if C_Timer and C_Timer.NewTimer then
      self.lootAggTimer = C_Timer.NewTimer(LOOT_AGG_WINDOW, function()
        Journal:CloseLootAggWindow()
      end)
    end
  end
end

local function MoneyAmountPattern(formatString)
  if not formatString or formatString == "" then
    return nil
  end
  local placeholder = "__NUM__"
  local pattern = formatString:gsub("%%d", placeholder)
  pattern = pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
  pattern = pattern:gsub(placeholder, "(%%d+)")
  return pattern
end

function Journal:ParseMoneyFromMessage(msg)
  if not msg then
    return 0
  end

  local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local copper = 0

  -- Parse gold, silver, copper from message
  -- Patterns: "You loot X Gold", "You loot X Silver", "You loot X Copper"
  -- Also handles combined: "You loot X Gold, Y Silver, Z Copper"
  local goldAmount = rawget(_G, "GOLD_AMOUNT") or "%d Gold"
  local silverAmount = rawget(_G, "SILVER_AMOUNT") or "%d Silver"
  local copperAmount = rawget(_G, "COPPER_AMOUNT") or "%d Copper"
  local goldPattern = MoneyAmountPattern(goldAmount) or "(%d+)%s*Gold"
  local silverPattern = MoneyAmountPattern(silverAmount) or "(%d+)%s*Silver"
  local copperPattern = MoneyAmountPattern(copperAmount) or "(%d+)%s*Copper"

  local gold = cleaned:match(goldPattern) or cleaned:match("(%d+)%s*gold")
  local silver = cleaned:match(silverPattern) or cleaned:match("(%d+)%s*silver")
  local copperMatch = cleaned:match(copperPattern) or cleaned:match("(%d+)%s*copper")

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

function Journal:RecordReputation(faction, change)
  if not faction or faction == "" then
    return
  end

  if self.inAggWindow then
    -- Add to aggregation window
    local rep = self.combatAgg.reputation
    rep[faction] = (rep[faction] or 0) + (change or 0)
    self:DebugLog("Rep aggregated: " .. faction .. " " .. (change >= 0 and "+" or "") .. change)
  else
    -- Not in aggregation window - log immediately
    if change then
      self:AddEvent("reputation", { faction = faction, change = change })
    else
      self:AddEvent("reputation", { faction = faction })
    end
  end
end

function Journal:RecordMoney(msg)
  if not msg or msg == "" then
    return
  end

  local copper = self:ParseMoneyFromMessage(msg)
  if self.debug then
    self:DebugLog("Money msg: " .. msg .. " -> " .. tostring(copper) .. "c")
  end
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

Journal:RegisterRenderer("activity", function(data)
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
end)

Journal:RegisterRenderer("xp", function(data)
  return "Gained " .. (data.amount or 0) .. " XP"
end)

Journal:RegisterRenderer("loot", function(data)
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
    local text = prefix .. ": " .. table.concat(parts, ", ")
    -- Add duration if this was aggregated over time
    if data.durationText then
      text = text .. " (over " .. data.durationText .. ")"
    end
    return text
  end
  return "Looted items"
end)

Journal:RegisterRenderer("death", function(data)
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
end)

Journal:RegisterRenderer("money", function(data)
  return "Looted: " .. Journal.FormatMoney(data.copper or 0)
end)

Journal.On("PLAYER_REGEN_ENABLED", function()
  Journal.inCombat = false
  -- Don't flush yet - start 10-second post-combat window for looting
  Journal:StartAggWindowTimer()
end)

Journal.On("PLAYER_REGEN_DISABLED", function()
  -- Flush previous aggregation window before starting new combat
  if Journal.inAggWindow then
    Journal:CloseAggWindow()
  end
  -- Also flush loot aggregation when combat starts
  if Journal.lootAgg and Journal.lootAgg.startTime then
    Journal:CloseLootAggWindow()
  end
  Journal.inCombat = true
  Journal.inAggWindow = true
end)

Journal.On("PLAYER_XP_UPDATE", function()
  Journal:RecordXP()
end)

Journal.On("COMBAT_LOG_EVENT_UNFILTERED", function()
  Journal:OnCombatLog()
end)

Journal.On("CHAT_MSG_LOOT", function(msg)
  Journal:RecordLoot(msg)
end)

Journal.On("CHAT_MSG_MONEY", function(msg)
  Journal:RecordMoney(msg)
end)

Journal.On("PLAYER_DEAD", function()
  Journal:RecordDeath()
end)
