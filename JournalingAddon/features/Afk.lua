local _, Journal = ...
Journal = Journal or _G.Journal or {}

-- Strip color codes from chat message (same as other features)
local function cleanMsg(msg)
  if not msg or msg == "" then return "" end
  return msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- CHAT_MSG_SYSTEM: "You are now AFK." / "You are no longer AFK."
-- Covers both /afk and inactivity-triggered AFK; uses system event type (hard cut).
Journal.On("CHAT_MSG_SYSTEM", function(msg)
  if not msg or msg == "" then return end
  local cleaned = cleanMsg(msg):lower()
  if cleaned:find("no longer afk") then
    Journal:AddEvent("system", { message = "Back." })
  elseif cleaned:find("now afk") or cleaned:find("are now afk") then
    Journal:AddEvent("system", { message = "AFK." })
  end
end)
