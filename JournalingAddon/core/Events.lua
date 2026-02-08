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
  "PLAYER_ENTERING_WORLD",
  "ZONE_CHANGED_NEW_AREA",
  "ZONE_CHANGED",
  "PLAYER_DEAD",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_LEVEL_UP",
  "UNIT_SPELLCAST_SUCCEEDED",
  "SCREENSHOT_SUCCEEDED",
  "CHAT_MSG_COMBAT_FACTION_CHANGE",
  "CHAT_MSG_SKILL",
  "CHAT_MSG_COMBAT_XP_GAIN",
  -- Party (TBC anniversary 20505 only; do not add GROUP_ROSTER_UPDATE or other-client events)
  "PARTY_INVITE_REQUEST",
  "PARTY_MEMBERS_CHANGED",
}

for _, eventName in ipairs(events) do
  frame:RegisterEvent(eventName)
end
