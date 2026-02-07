local _, Journal = ...
Journal = Journal or _G.Journal or {}

local CURRENT_SCHEMA = 3
Journal.CURRENT_SCHEMA = CURRENT_SCHEMA

local function BackupKey()
  return "backup_" .. date("!%Y%m%dT%H%M%SZ")
end

function Journal:ResetDatabase(keepBackup)
  local old = JournalDB
  JournalDB = {}
  if keepBackup and old then
    JournalDB[BackupKey()] = old
  end
  JournalDB.schemaVersion = CURRENT_SCHEMA
  JournalDB.sessions = {}
  self.db = JournalDB
  self.currentSession = nil
end

function Journal:InitDB()
  if not JournalDB or JournalDB.schemaVersion ~= CURRENT_SCHEMA then
    self:ResetDatabase(self.debug)
  else
    JournalDB.sessions = JournalDB.sessions or {}
    self.db = JournalDB
  end
  JournalDB.settings = JournalDB.settings or {}
  if JournalDB.settings.afkNoteMinutes == nil then
    JournalDB.settings.afkNoteMinutes = 10
  end
  if JournalDB.settings.loginNoteMinutes == nil then
    JournalDB.settings.loginNoteMinutes = 30
  end
  if self.reloadPending and self.db and not self.db.reloadPending then
    self.db.reloadPending = true
  end
end

function Journal:GetSetting(name, defaultValue)
  if JournalDB and JournalDB.settings and JournalDB.settings[name] ~= nil then
    return JournalDB.settings[name]
  end
  return defaultValue
end

function Journal:MarkReloadPending()
  self.isReloading = true
  self.reloadPending = true
  if JournalDB then
    JournalDB.reloadPending = true
  end
end

local function HookReloadUI()
  if Journal.reloadHooked then
    return
  end
  local reloadUI = rawget(_G, "ReloadUI")
  if hooksecurefunc and reloadUI then
    hooksecurefunc("ReloadUI", function()
      Journal:MarkReloadPending()
    end)
    Journal.reloadHooked = true
  end
end

HookReloadUI()

function Journal:InitState()
  self.agg = {
    xp = { lastXP = nil, lastMaxXP = nil },
    damage = { events = {} },
  }
  self.lastZone = GetRealZoneText()
  self.lastSubZone = GetSubZoneText()
  -- Note: inCombat may still be used for other purposes (e.g., damage tracking)
  self.inCombat = UnitAffectingCombat("player") or false
  if self.ResetActivityChunk then
    self:ResetActivityChunk()
  end
  self.idleTimer = nil
  self.hardCapTimer = nil
  self.lastQuestCompleted = nil
  self.lastHearthCastAt = nil
  self.lastHearthFrom = nil
  self.lastLevelUpAt = nil  -- Track level up time to add XP gain to previous chunk
  if self.ResetSkillAgg then
    self:ResetSkillAgg()
  end
  self.skillAggTimer = nil
  self.lastSkillChunkEnd = nil  -- cleared on new session; used for continuous skill range across chunks
  self.eventSeqCounter = 0  -- Sequence counter for stable event ordering
  self.recentKillXP = {}  -- Track recent kill XP amounts to suppress duplicate PLAYER_XP_UPDATE
  self.recentDiscoveryXP = {}  -- Track recent discovery XP amounts to suppress duplicate PLAYER_XP_UPDATE
  self.lastHardFlushTime = nil  -- Unix time when last hard flush occurred (prevents new chunks during window)
  self.lastFlushedLootEntry = nil  -- Reference to last loot entry from flushed chunk (for retroactive updates)
  self.isReloading = false
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
  if not self.db then
    return
  end
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

function Journal:StartNewSession(message)
  if not self.db then
    return
  end
  if self.currentSession and not self.currentSession.endTime then
    self.currentSession.endTime = time()
  end
  local characterKey = self:GetCharacterKey()
  local dayKey = self:GetDayKey()
  local session = {
    startTime = time(),
    endTime = nil,
    entries = {},
    characterKey = characterKey,
    dayKey = dayKey,
  }
  table.insert(self.db.sessions, session)
  self.currentSession = session
  self:AddEvent("system", { message = message or "Session started." })
end

function Journal:EndSession()
  if self.currentSession and not self.currentSession.endTime then
    -- Flush activity chunk on logout
    if self.FlushActivityChunk then
      self:FlushActivityChunk()
    end
    -- Flush skill aggregation on logout
    if self.CloseSkillAggWindow then
      self:CloseSkillAggWindow()
    end
    self.currentSession.endTime = time()
  end
end

-- Create a structured event
function Journal:CreateEvent(eventType, data, overrideTimestamp)
  -- Increment sequence counter for stable ordering when timestamps are identical
  self.eventSeqCounter = (self.eventSeqCounter or 0) + 1
  return {
    v = CURRENT_SCHEMA,
    ts = overrideTimestamp or Journal.ISOTimestamp(),  -- Use override timestamp if provided, otherwise current time
    seq = self.eventSeqCounter,   -- Sequence number for stable ordering
    type = eventType,
    data = data,
    msg = self:RenderMessage(eventType, data),
  }
end

-- Add event with optional timestamp override (for flush operations)
function Journal:AddEventWithTimestamp(eventType, data, timestamp)
  if not self.currentSession then
    return
  end
  
  local event = self:CreateEvent(eventType, data, timestamp)
  table.insert(self.currentSession.entries, event)
  if self.debug then
    self:DebugLog("Event added: " .. eventType .. " - " .. event.msg)
  end
  if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
    self:RefreshUI()
  end
  return event  -- Return event for potential retroactive updates
end

-- Check if an event is a hard cut event that should flush activity chunk
function Journal:IsHardCutEvent(eventType, data)
  if eventType == "quest" and data and (data.action == "accepted" or data.action == "turned_in") then
    return true
  elseif eventType == "level" then
    return true
  elseif eventType == "screenshot" then
    return true
  elseif eventType == "note" then
    return true
  elseif eventType == "discovery" then
    return true
  elseif eventType == "death" then
    return true
  elseif eventType == "travel" and data and (data.action == "zone_change" or data.action == "subzone_change" or data.action == "flight_start") then
    return true
  elseif eventType == "system" then
    return true
  end
  return false
end

-- New event-first entry creation
function Journal:AddEvent(eventType, data)
  if not self.currentSession then
    return
  end
  
  -- Flush activity chunk if this is a hard cut event
  if self:IsHardCutEvent(eventType, data) and self.FlushActivityChunk then
    self:FlushActivityChunk()
    -- Mark that a hard flush just occurred (prevents new chunks during window)
    self.lastHardFlushTime = time()
    -- Clear last flushed loot entry after window expires (11 seconds to ensure cleanup)
    if C_Timer and C_Timer.NewTimer then
      C_Timer.NewTimer(11, function()
        self.lastFlushedLootEntry = nil
      end)
    end
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
  -- Increment sequence counter for stable ordering when timestamps are identical
  self.eventSeqCounter = (self.eventSeqCounter or 0) + 1
  local event = {
    v = CURRENT_SCHEMA,
    ts = Journal.ISOTimestamp(),  -- Always use current time at creation (time of insert)
    seq = self.eventSeqCounter,   -- Sequence number for stable ordering
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

function Journal:RemoveLastEntry()
  if not self.currentSession or not self.currentSession.entries then
    return nil
  end
  return table.remove(self.currentSession.entries)
end

function Journal:ClearCurrentSession()
  if not self.currentSession then
    return 0
  end
  local count = self.currentSession.entries and #self.currentSession.entries or 0
  self.currentSession.entries = {}
  return count
end

function Journal:WipeAllData()
  self:ResetDatabase(self.debug)
  self:InitState()
  self:StartSession()
end

function Journal:DebugLog(message)
  if not self.debug then
    return
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r " .. message)
  end
end

Journal.On("PLAYER_LOGIN", function()
  Journal:InitDB()
  Journal:InitState()
  Journal:StartSession()
  local wasReload = Journal.db and Journal.db.reloadPending or false
  local lastLogoutAt = JournalDB and JournalDB.lastLogoutAt or nil
  if Journal.db then
    Journal.db.reloadPending = nil
  end
  Journal.reloadPending = nil
  local loginEvent = nil
  if not wasReload then
    Journal:AddEvent("system", { message = "Logged in." })
    if Journal.currentSession and Journal.currentSession.entries then
      loginEvent = Journal.currentSession.entries[#Journal.currentSession.entries]
    end
  end
  Journal.agg.xp.lastXP = UnitXP("player")
  Journal.agg.xp.lastMaxXP = UnitXPMax("player")
  if Journal.InitUI then
    Journal:InitUI()
  end
  if loginEvent and lastLogoutAt and Journal.MaybePromptAwayNote then
    local idleSeconds = time() - lastLogoutAt
    if idleSeconds and idleSeconds > 0 then
      Journal:MaybePromptAwayNote(loginEvent, "login", idleSeconds)
    end
  end
end)

Journal.On("PLAYER_LOGOUT", function()
  if Journal.isReloading or (Journal.db and Journal.db.reloadPending) then
    return
  end
  if JournalDB then
    JournalDB.lastLogoutAt = time()
  end
  Journal:AddEvent("system", { message = "Logged out." })
  Journal:EndSession()
end)
