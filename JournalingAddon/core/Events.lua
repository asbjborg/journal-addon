local _, Journal = ...
Journal = Journal or _G.Journal or {}

local frame = CreateFrame("Frame")
Journal.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
  Journal.Emit(event, ...)
end)

local events = {
  "PLAYER_LOGIN",
  "PLAYER_LOGOUT",
  "QUEST_ACCEPTED",
  "QUEST_TURNED_IN",
  "CHAT_MSG_SYSTEM",
  "PLAYER_XP_UPDATE",
  "COMBAT_LOG_EVENT_UNFILTERED",
  "CHAT_MSG_LOOT",
  "CHAT_MSG_MONEY",
  "PLAYER_CONTROL_LOST",
  "PLAYER_CONTROL_GAINED",
  "ZONE_CHANGED_NEW_AREA",
  "PLAYER_DEAD",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_LEVEL_UP",
  "UNIT_SPELLCAST_SUCCEEDED",
  "SCREENSHOT_SUCCEEDED",
  "CHAT_MSG_COMBAT_FACTION_CHANGE",
  "CHAT_MSG_SKILL",
}

for _, eventName in ipairs(events) do
  frame:RegisterEvent(eventName)
end
