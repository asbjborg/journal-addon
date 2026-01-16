local _, Journal = ...
Journal = Journal or _G.Journal or {}

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

Journal:RegisterRenderer("reputation", function(data)
  if data.tier then
    return "Reputation tier: " .. data.tier .. " with " .. (data.faction or "Unknown")
  elseif data.amount then
    return "Reputation with " .. (data.faction or "Unknown") .. " increased by " .. data.amount
  else
    return "Reputation with " .. (data.faction or "Unknown") .. " increased"
  end
end)

Journal.On("CHAT_MSG_SYSTEM", function(msg)
  if msg and msg ~= "" then
    local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local repTier = cleaned:match("^You are now (.+) with (.+)%.$")
    if repTier then
      local tier, faction = repTier:match("^(.+) with (.+)$")
      if tier and faction then
        Journal:AddEvent("reputation", {
          faction = faction,
          tier = tier,
        })
      end
    end
  end
end)

Journal.On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(msg)
  if msg and msg ~= "" then
    Journal:HandleReputationChange(msg)
  end
end)
