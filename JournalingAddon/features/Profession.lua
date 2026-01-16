local _, Journal = ...
Journal = Journal or _G.Journal or {}

Journal:RegisterRenderer("profession", function(data)
  return (data.skill or "Unknown") .. " skill increased to " .. (data.level or "?")
end)

Journal.On("CHAT_MSG_SKILL", function(msg)
  if not msg or msg == "" then
    return
  end

  local skill, level = msg:match("Your skill in (.+) has increased to (%d+)")
  if skill and level then
    Journal:DebugLog("Skill up: " .. skill .. " -> " .. level)
    Journal:AddEvent("profession", {
      skill = skill,
      level = tonumber(level),
    })
  end
end)
