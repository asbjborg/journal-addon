local _, Journal = ...
Journal = Journal or _G.Journal or {}

local DAMAGE_WINDOW = 10
local RESUME_WINDOW = 30  -- 30 seconds resume window for activity chunk
local HARD_CAP_WINDOW = 180  -- 3 minutes hard cap for activity chunk
local QUEST_REWARD_WINDOW = 10  -- Seconds after quest turn-in to consider loot as quest reward
local KILL_XP_SUPPRESSION_WINDOW = 2  -- Seconds to suppress PLAYER_XP_UPDATE that matches kill XP
local DISCOVERY_XP_SUPPRESSION_WINDOW = 3  -- Seconds to suppress PLAYER_XP_UPDATE that matches discovery XP
local HARD_FLUSH_WINDOW = 10  -- Seconds after hard flush where new chunks cannot start (late-arriving loot logged immediately)

function Journal:ResetActivityChunk()
  self.activityChunk = {
    kills = {},
    xp = 0,
    loot = { counts = {}, raw = {}, action = nil },
    money = 0,
    reputation = {},  -- { [faction] = change }
    startTime = nil,
    lastActivityTime = nil,
  }
end

function Journal:StartActivityChunk()
  -- Initialize activity chunk if not already started
  if not self.activityChunk then
    self:ResetActivityChunk()
  end
  
  local now = time()
  -- Set start time if not already set (for hard cap timer)
  if not self.activityChunk.startTime then
    self.activityChunk.startTime = now
    -- Start hard cap timer (3 minutes, never resets)
    if C_Timer and C_Timer.NewTimer then
      if self.hardCapTimer then
        self.hardCapTimer:Cancel()
      end
      self.hardCapTimer = C_Timer.NewTimer(HARD_CAP_WINDOW, function()
        Journal:FlushActivityChunk()
      end)
    end
  end
  
  -- Update last activity time
  self.activityChunk.lastActivityTime = now
  
  -- Reset idle timer (30 seconds, resets on every activity)
  if self.idleTimer then
    self.idleTimer:Cancel()
    self.idleTimer = nil
  end
  if C_Timer and C_Timer.NewTimer then
    self.idleTimer = C_Timer.NewTimer(RESUME_WINDOW, function()
      Journal:FlushActivityChunk()
    end)
  end
end

function Journal:FlushActivityChunk()
  -- Cancel both timers
  if self.idleTimer then
    self.idleTimer:Cancel()
    self.idleTimer = nil
  end
  if self.hardCapTimer then
    self.hardCapTimer:Cancel()
    self.hardCapTimer = nil
  end
  
  if not self.currentSession or not self.activityChunk then
    self:ResetActivityChunk()
    return
  end

  -- Capture a single timestamp for all entries flushed from this chunk
  -- This ensures kill, loot, money, and rep entries appear together in chronological order
  local flushTimestamp = Journal.ISOTimestamp()
  local startTs = nil
  local endTs = flushTimestamp
  if self.activityChunk.startTime then
    startTs = Journal.ISOTimestamp(self.activityChunk.startTime)
  end

  local killCounts = self.activityChunk.kills
  local xpTotal = self.activityChunk.xp
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

    -- Calculate duration
    local duration = nil
    if self.activityChunk.startTime then
      duration = time() - self.activityChunk.startTime
    end

    local eventData = {
      xp = xpTotal > 0 and xpTotal or nil,
      duration = duration,  -- Store raw duration in seconds for renderer to format
    }
    if startTs then
      eventData.startTs = startTs
      eventData.endTs = endTs
    end

    if targetCount == 1 then
      -- Single target type - use cleaner format
      eventData.target = singleTarget
      eventData.count = singleCount
    elseif targetCount > 1 then
      -- Multiple targets - use kills map
      eventData.kills = Journal.CopyTable(killCounts)
    end

    self:AddEventWithTimestamp("activity", eventData, flushTimestamp)
  end

  local lootCounts = self.activityChunk.loot.counts
  if next(lootCounts) then
    local duration = nil
    if self.activityChunk.startTime then
      duration = time() - self.activityChunk.startTime
    end
    local lootData = {
      action = self.activityChunk.loot.action or "loot",
      counts = Journal.CopyTable(self.activityChunk.loot.counts),
      raw = Journal.CopyTable(self.activityChunk.loot.raw),
      duration = duration,  -- Store raw duration in seconds for renderer to format
    }
    if startTs then
      lootData.startTs = startTs
      lootData.endTs = endTs
    end
    local lootEvent = self:AddEventWithTimestamp("loot", lootData, flushTimestamp)
    -- Store reference to this loot entry for retroactive updates during hard flush window
    self.lastFlushedLootEntry = lootEvent
  else
    self.lastFlushedLootEntry = nil
  end

  local money = self.activityChunk.money
  if money and money > 0 then
    local duration = nil
    if self.activityChunk.startTime then
      duration = time() - self.activityChunk.startTime
    end
    local moneyData = {
      copper = money,
      duration = duration,  -- Store raw duration in seconds for renderer to format
    }
    if startTs then
      moneyData.startTs = startTs
      moneyData.endTs = endTs
    end
    self:AddEventWithTimestamp("money", moneyData, flushTimestamp)
  end

  local reputation = self.activityChunk.reputation
  if reputation and next(reputation) then
    local repData = { changes = Journal.CopyTable(reputation) }
    if startTs then
      repData.startTs = startTs
      repData.endTs = endTs
    end
    self:AddEventWithTimestamp("reputation", repData, flushTimestamp)
  end

  self:ResetActivityChunk()
  
  -- Clear last flushed loot entry after a delay (so it can be updated during window)
  -- It will be cleared when a new flush happens or when window expires
end

function Journal:RecordKill(destName)
  if not destName or destName == "" then
    return
  end

  self:EnsureActivityChunk()
  
  -- Add kill to chunk
  local counts = self.activityChunk.kills
  counts[destName] = (counts[destName] or 0) + 1
end

function Journal:RecordCombatXP(msg)
  if not msg or msg == "" then
    return
  end
  
  -- Parse XP amount from message: "%s dies, you gain %d experience." or "You gain %d experience."
  -- Check if it's kill XP (contains "dies")
  local isKillXP = msg:match("dies")
  local xpAmount = tonumber(msg:match("(%d+) experience"))
  
  if not xpAmount or xpAmount <= 0 then
    return
  end
  
  -- Only handle kill XP here (from "dies" messages)
  -- Quest/other XP will be handled by PLAYER_XP_UPDATE
  if isKillXP then
    local now = time()
    
    -- Track this kill XP for suppression window
    table.insert(self.recentKillXP, {
      amount = xpAmount,
      timestamp = now,
    })
    
    -- Clean up old entries (older than suppression window)
    while #self.recentKillXP > 0 and (now - self.recentKillXP[1].timestamp) > KILL_XP_SUPPRESSION_WINDOW do
      table.remove(self.recentKillXP, 1)
    end
    
    -- Add kill XP directly to activity chunk
    self:EnsureActivityChunk()
    self.activityChunk.xp = (self.activityChunk.xp or 0) + xpAmount
    self.activityChunk.lastActivityTime = now
    
    -- Reset idle timer
    if self.idleTimer then
      self.idleTimer:Cancel()
      self.idleTimer = nil
    end
    if C_Timer and C_Timer.NewTimer then
      self.idleTimer = C_Timer.NewTimer(RESUME_WINDOW, function()
        Journal:FlushActivityChunk()
      end)
    end
    
    -- Update last XP tracking to prevent double-counting in RecordXP
    if self.agg.xp.lastXP then
      local currentXP = UnitXP("player")
      local currentMax = UnitXPMax("player")
      self.agg.xp.lastXP = currentXP
      self.agg.xp.lastMaxXP = currentMax
    end
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
    local now = time()
    
    -- Check if this XP matches recent kill XP (suppress duplicate)
    if self.recentKillXP and #self.recentKillXP > 0 then
      -- Clean up old entries first
      while #self.recentKillXP > 0 and (now - self.recentKillXP[1].timestamp) > KILL_XP_SUPPRESSION_WINDOW do
        table.remove(self.recentKillXP, 1)
      end
      
      -- Check if any recent kill XP matches this delta
      for _, killXP in ipairs(self.recentKillXP) do
        if killXP.amount == delta then
          -- This XP matches recent kill XP - suppress it (already counted in RecordCombatXP)
          self.agg.xp.lastXP = currentXP
          self.agg.xp.lastMaxXP = currentMax
          return
        end
      end
    end
    
    -- Check if this XP matches recent discovery XP (suppress duplicate)
    if self.recentDiscoveryXP and #self.recentDiscoveryXP > 0 then
      -- Clean up old entries first
      while #self.recentDiscoveryXP > 0 and (now - self.recentDiscoveryXP[1].timestamp) > DISCOVERY_XP_SUPPRESSION_WINDOW do
        table.remove(self.recentDiscoveryXP, 1)
      end
      
      -- Check if any recent discovery XP matches this delta
      for _, discoveryXP in ipairs(self.recentDiscoveryXP) do
        if discoveryXP.amount == delta then
          -- This XP matches recent discovery XP - suppress it (already logged in discovery event)
          self.agg.xp.lastXP = currentXP
          self.agg.xp.lastMaxXP = currentMax
          return
        end
      end
    end
    
    -- If XP gain comes immediately after level up (within 1 second), it belongs to the previous chunk
    if self.lastLevelUpAt and (now - self.lastLevelUpAt) <= 1 then
      -- XP gain from level up - this should have been in the previous chunk
      -- Since chunk is already flushed, we need to add this XP to the last activity entry
      -- Find the last activity entry and add XP to it
      if self.currentSession and self.currentSession.entries then
        for i = #self.currentSession.entries, 1, -1 do
          local entry = self.currentSession.entries[i]
          if entry.type == "activity" and entry.data then
            -- Add XP to this activity entry
            entry.data.xp = (entry.data.xp or 0) + delta
            -- Update the message
            entry.msg = self:RenderMessage("activity", entry.data)
            if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
              self:RefreshUI()
            end
            self.agg.xp.lastXP = currentXP
            self.agg.xp.lastMaxXP = currentMax
            return
          end
        end
      end
    end
    
    -- Check if there's an active chunk with actual activity (kills, loot, money, reputation)
    -- XP gain alone should not start a chunk - only add to existing active chunks
    local hasActiveChunk = false
    if self.activityChunk and self.activityChunk.lastActivityTime then
      -- Check if chunk has actual activity (not just XP)
      if next(self.activityChunk.kills) or 
         next(self.activityChunk.loot.counts) or 
         (self.activityChunk.money and self.activityChunk.money > 0) or
         next(self.activityChunk.reputation) then
        -- Chunk has actual activity - check if within resume window
        if (now - self.activityChunk.lastActivityTime) <= RESUME_WINDOW then
          hasActiveChunk = true
        end
      end
    end
    
    if hasActiveChunk then
      -- Add XP to existing active chunk
      self.activityChunk.xp = self.activityChunk.xp + delta
      -- Update last activity time and reset idle timer
      self.activityChunk.lastActivityTime = now
      if self.idleTimer then
        self.idleTimer:Cancel()
        self.idleTimer = nil
      end
      if C_Timer and C_Timer.NewTimer then
        self.idleTimer = C_Timer.NewTimer(RESUME_WINDOW, function()
          Journal:FlushActivityChunk()
        end)
      end
    else
      -- No active chunk with actual activity - log XP immediately without chunk
      -- This handles quest rewards, zone discovery, and other isolated XP gains
      self:AddEvent("xp", { amount = delta })
    end
  end

  self.agg.xp.lastXP = currentXP
  self.agg.xp.lastMaxXP = currentMax
end

-- Helper function to convert WoW format string to Lua pattern
local function escapePattern(s)
  if not s or s == "" then return nil end
  -- Replace format placeholders with temporary placeholders first
  s = s:gsub("%%(%d%$)?s", "__STRING_PLACEHOLDER__")
  s = s:gsub("%%(%d%$)?d", "__NUMBER_PLACEHOLDER__")
  -- Escape all Lua pattern special characters
  s = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
  -- Replace placeholders with capture patterns
  s = s:gsub("__STRING_PLACEHOLDER__", "(.+)")
  s = s:gsub("__NUMBER_PLACEHOLDER__", "(%%d+)")
  return "^" .. s .. "$"
end

-- Normalize player name (strip realm suffix, raid icons, color codes, and whitespace)
local function normalizeName(name)
  if not name then return nil end
  -- Trim whitespace
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  -- Strip color codes (|c[0-9A-Fa-f]{8} and |r)
  name = name:gsub("|c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]", "")
  name = name:gsub("|r", "")
  -- Strip raid target icons ({rt1} through {rt8})
  name = name:gsub("{rt%d}", "")
  -- Strip realm suffix (-RealmName)
  name = name:match("([^%-]+)") or name
  return name
end

-- Cache for built loot patterns
local LOOT_PATTERNS = nil

-- Build loot patterns from WoW's global format strings
local function buildLootPatterns()
  if LOOT_PATTERNS then return LOOT_PATTERNS end

  local function pat(fmt) 
    if not fmt or fmt == "" then return nil end
    return escapePattern(fmt)
  end

  LOOT_PATTERNS = {
    self = {
      pat(_G.LOOT_ITEM_SELF),
      pat(_G.LOOT_ITEM_SELF_MULTIPLE),
      pat(_G.LOOT_ITEM_PUSHED_SELF),
      pat(_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE),
    },
    other = {
      pat(_G.LOOT_ITEM),
      pat(_G.LOOT_ITEM_MULTIPLE),
      pat(_G.LOOT_ITEM_PUSHED),
      pat(_G.LOOT_ITEM_PUSHED_MULTIPLE),
    }
  }

  return LOOT_PATTERNS
end

-- Parse loot chat message and determine if it should be recorded
-- Returns: shouldRecord (bool), itemLink (string), count (number)
-- 
-- Pattern matching order is critical:
-- 1. Check self patterns first (always record if matched)
-- 2. Check other patterns and verify recipient == player name
--    (Some locales/settings may use "PlayerName receives loot" even for self)
-- 3. Fallback to "You" patterns for create/craft messages
local function parseLootChatMessage(msg)
  if not msg or msg == "" then
    return false
  end

  local patterns = buildLootPatterns()
  local myName = normalizeName(UnitName("player"))

  -- Extract itemLink first (works for all loot messages)
  -- Item links are always present in loot messages and are more reliable than text matching
  local itemLink = msg:match("|Hitem:.-|h%[.-%]|h")
  if not itemLink then
    return false
  end

  -- 1) Try self variants first (always record if matched)
  -- LOOT_ITEM_SELF: "You receive loot: %s." -> captures (item), count defaults to 1
  -- LOOT_ITEM_SELF_MULTIPLE: "You receive loot: %sx%d." -> captures (item, count)
  for _, p in ipairs(patterns.self) do
    if p then
      local a, b = msg:match(p)
      if a then
        local count = tonumber(b) or 1
        return true, itemLink, count
      end
    end
  end

  -- 2) Try other variants (must verify recipient is player)
  -- LOOT_ITEM: "%s receives loot: %s." -> captures (recipient, item), count defaults to 1
  -- LOOT_ITEM_MULTIPLE: "%s receives loot: %sx%d." -> captures (recipient, item, count)
  for _, p in ipairs(patterns.other) do
    if p then
      local recipient, item, maybeCount = msg:match(p)
      if recipient and item then
        recipient = normalizeName(recipient)
        if recipient == myName then
          -- Player name matches - this is player loot (some locales use this format for self)
          local count = tonumber(maybeCount) or 1
          return true, itemLink, count
        else
          -- Party member loot - don't record
          return false
        end
      end
    end
  end

  -- 3) Fallback: check for "You" patterns (for create/craft which may not use LOOT_ITEM_SELF)
  if msg:match("You create:") or msg:match("You craft:") or msg:match("You receive item:") or msg:match("You receive loot:") then
    local count = tonumber(msg:match("x(%d+)")) or 1
    return true, itemLink, count
  end

  return false
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

-- Helper function to ensure activity chunk is active and update timers
function Journal:EnsureActivityChunk()
  local now = time()
  
  -- Check if we should start a new chunk or continue existing one
  if not self.activityChunk or not self.activityChunk.lastActivityTime or (now - self.activityChunk.lastActivityTime) > RESUME_WINDOW then
    -- Gap > 30 seconds - flush existing chunk and start new one
    if self.activityChunk and self.activityChunk.lastActivityTime then
      self:FlushActivityChunk()
    end
    
    -- Check if we're in a hard flush window - if so, don't start new chunks
    if self.lastHardFlushTime and (now - self.lastHardFlushTime) <= 10 then
      -- Within hard flush window - don't start new chunks, return false to indicate no chunk
      return false
    end
    
    self:StartActivityChunk()
  else
    -- Within resume window - continue existing chunk
    if not self.activityChunk then
      -- Check if we're in a hard flush window - if so, don't start new chunks
      if self.lastHardFlushTime and (now - self.lastHardFlushTime) <= 10 then
        -- Within hard flush window - don't start new chunks, return false to indicate no chunk
        return false
      end
      self:StartActivityChunk()
    else
      -- Update last activity time and reset idle timer
      self.activityChunk.lastActivityTime = now
      if self.idleTimer then
        self.idleTimer:Cancel()
        self.idleTimer = nil
      end
      if C_Timer and C_Timer.NewTimer then
        self.idleTimer = C_Timer.NewTimer(RESUME_WINDOW, function()
          Journal:FlushActivityChunk()
        end)
      end
    end
  end
  return true
end

function Journal:RecordLoot(msg)
  if not msg or msg == "" then
    return
  end

  -- Parse loot message - only records if it's for the player
  local shouldRecord, itemLink, count = parseLootChatMessage(msg)
  if not shouldRecord or not itemLink then
    return
  end

  -- Extract item name from itemLink
  local itemName = itemLink:match("%[(.-)%]")
  if not itemName then
    return
  end

  -- Clean item name (remove quantity suffix if present)
  itemName = itemName:gsub("x%d+$", ""):gsub("%s+$", "")

  local action = self:DetectLootAction(msg)

  -- Check if this is a quest reward (should be logged immediately, bypass aggregation)
  local now = time()
  local isQuestReward = false
  if self.lastQuestTurnedIn and (now - self.lastQuestTurnedIn) < QUEST_REWARD_WINDOW then
    -- Loot received within quest reward window - treat as quest reward and log immediately
    isQuestReward = true
  end
  
  if isQuestReward then
    -- Quest reward - log immediately, bypass activity chunk aggregation
    self:AddEvent("loot", {
      action = action,
      counts = { [itemName] = count },
      raw = { msg },
    })
  else
    -- Check if we're in a hard flush window - if so, try to update last flushed loot entry
    if self.lastHardFlushTime and (now - self.lastHardFlushTime) <= 10 then
      -- Within hard flush window - try to retroactively update last flushed loot entry
      if self.lastFlushedLootEntry and self.lastFlushedLootEntry.data and self.lastFlushedLootEntry.data.counts then
        -- Update the last loot entry with new loot
        local counts = self.lastFlushedLootEntry.data.counts
        counts[itemName] = (counts[itemName] or 0) + count
        if self.lastFlushedLootEntry.data.raw then
          table.insert(self.lastFlushedLootEntry.data.raw, msg)
        end
        -- Re-render the message with updated counts
        self.lastFlushedLootEntry.msg = self:RenderMessage("loot", self.lastFlushedLootEntry.data)
        if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
          self:RefreshUI()
        end
        return
      else
        -- No loot entry to update - log immediately without duration
        self:AddEvent("loot", {
          action = action,
          counts = { [itemName] = count },
          raw = { msg },
          -- No duration - appears immediately after hard flush event
        })
        return
      end
    end
    
    -- Not a quest reward and not in hard flush window - add to activity chunk
    if self:EnsureActivityChunk() then
      local counts = self.activityChunk.loot.counts
      counts[itemName] = (counts[itemName] or 0) + count
      table.insert(self.activityChunk.loot.raw, msg)
      -- Store action for loot (use first seen action)
      if not self.activityChunk.loot.action then
        self.activityChunk.loot.action = action
      end
    else
      -- Couldn't create chunk (in hard flush window) - log immediately
      self:AddEvent("loot", {
        action = action,
        counts = { [itemName] = count },
        raw = { msg },
      })
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

  -- Only aggregate if we have a numeric change
  if change then
    self:EnsureActivityChunk()
    
    local rep = self.activityChunk.reputation
    rep[faction] = (rep[faction] or 0) + change
    self:DebugLog("Rep aggregated: " .. faction .. " " .. (change >= 0 and "+" or "") .. change)
  else
    -- No numeric change (vague reputation change) - log immediately
    self:AddEvent("reputation", { faction = faction })
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

  local now = time()
  
  -- Check if we're in a hard flush window - if so, log immediately without duration
  if self.lastHardFlushTime and (now - self.lastHardFlushTime) <= 10 then
    -- Within hard flush window - log immediately without duration (not aggregated)
    -- This handles late-arriving money from the kill that just got flushed
    self:AddEvent("money", { copper = copper })
    return
  end

  -- Not in hard flush window - add to activity chunk
  if self:EnsureActivityChunk() then
    -- Add money to chunk
    self.activityChunk.money = self.activityChunk.money + copper
  else
    -- Couldn't create chunk (in hard flush window) - log immediately
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
  
  -- Add duration if present and > 0 (similar to loot entries)
  if data.duration and data.duration > 0 then
    local minutes = math.floor(data.duration / 60)
    local seconds = data.duration % 60
    -- Format duration: "Xm" if >= 60s, otherwise "Xs"
    local durationText = minutes > 0 and (minutes .. "m") or (seconds .. "s")
    table.insert(parts, "(over " .. durationText .. ")")
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
    -- Add duration if this was aggregated over time and > 0
    if data.duration and data.duration > 0 then
      local minutes = math.floor(data.duration / 60)
      local seconds = data.duration % 60
      -- Format duration: "Xm" if >= 60s, otherwise "Xs"
      local durationText = minutes > 0 and (minutes .. "m") or (seconds .. "s")
      text = text .. " (over " .. durationText .. ")"
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
  local text = "Looted: " .. Journal.FormatMoney(data.copper or 0)
  -- Add duration if this was aggregated over time and > 0
  if data.duration and data.duration > 0 then
    local minutes = math.floor(data.duration / 60)
    local seconds = data.duration % 60
    -- Format duration: "Xm" if >= 60s, otherwise "Xs"
    local durationText = minutes > 0 and (minutes .. "m") or (seconds .. "s")
    text = text .. " (over " .. durationText .. ")"
  end
  return text
end)

-- Note: PLAYER_REGEN_ENABLED/DISABLED are no longer used for aggregation
-- Activity chunk is now time-based, not combat-based
-- These events may still be used for other purposes (e.g., damage tracking for death events)

Journal.On("PLAYER_XP_UPDATE", function()
  Journal:RecordXP()
end)

Journal.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  Journal:RecordCombatXP(msg)
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
