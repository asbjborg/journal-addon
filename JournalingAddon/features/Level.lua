local _, Journal = ...
Journal = Journal or _G.Journal or {}

Journal:RegisterRenderer("level", function(data)
  return "Leveled up to " .. (data.level or "?") .. "!"
end)

Journal.On("PLAYER_LEVEL_UP", function(level)
  -- Track level up time to prevent XP gain from starting new chunk immediately after
  Journal.lastLevelUpAt = time()
  Journal:AddEvent("level", { level = level })
end)
