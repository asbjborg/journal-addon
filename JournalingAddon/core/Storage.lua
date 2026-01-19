local _, Journal = ...
Journal = Journal or _G.Journal or {}

local CURRENT_SCHEMA = 2
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
end

function Journal:InitState()
  self.agg = {
    xp = { lastXP = nil, lastMaxXP = nil },
    damage = { events = {} },
  }
  self.lastZone = GetRealZoneText()
  self.lastSubZone = GetSubZoneText()
  self.inCombat = UnitAffectingCombat("player") or false
  self.inAggWindow = self.inCombat
  self.aggWindowTimer = nil
  if self.ResetCombatAgg then
    self:ResetCombatAgg()
  end
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
    if self.inAggWindow and self.CloseAggWindow then
      self:CloseAggWindow()
    end
    -- Also flush loot aggregation on logout
    if self.lootAgg and self.lootAgg.startTime and self.CloseLootAggWindow then
      self:CloseLootAggWindow()
    end
    self.currentSession.endTime = time()
  end
end

-- Create a structured event
function Journal:CreateEvent(eventType, data)
  return {
    v = CURRENT_SCHEMA,
    ts = Journal.ISOTimestamp(),
    type = eventType,
    data = data,
    msg = self:RenderMessage(eventType, data),
  }
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
    v = CURRENT_SCHEMA,
    ts = Journal.ISOTimestamp(),
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
  Journal.agg.xp.lastXP = UnitXP("player")
  Journal.agg.xp.lastMaxXP = UnitXPMax("player")
  if Journal.InitUI then
    Journal:InitUI()
  end
end)

Journal.On("PLAYER_LOGOUT", function()
  Journal:EndSession()
end)
