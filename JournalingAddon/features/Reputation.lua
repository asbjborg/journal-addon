local _, Journal = ...
Journal = Journal or _G.Journal or {}

function Journal:HandleReputationChange(msg)
  local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

  -- Check for increase with amount
  local faction, amount = cleaned:match("Your reputation with (.+) has increased by (%d+)")
  if not faction then
    faction, amount = cleaned:match("Reputation with (.+) increased by (%d+)")
  end
  if faction and amount then
    self:RecordReputation(faction, tonumber(amount))
    return
  end

  -- Check for decrease with amount
  faction, amount = cleaned:match("Your reputation with (.+) has decreased by (%d+)")
  if not faction then
    faction, amount = cleaned:match("Reputation with (.+) decreased by (%d+)")
  end
  if faction and amount then
    self:RecordReputation(faction, -tonumber(amount))
    return
  end

  -- Vague increase (no amount) - log immediately (rare, not combat-related)
  faction = cleaned:match("Your reputation with (.+) has .* increased")
  if not faction then
    faction = cleaned:match("Reputation with (.+) increased")
  end
  if faction then
    self:AddEvent("reputation", { faction = faction })
    return
  end

  -- Vague decrease (no amount) - log immediately
  faction = cleaned:match("Your reputation with (.+) has .* decreased")
  if not faction then
    faction = cleaned:match("Reputation with (.+) decreased")
  end
  if faction then
    self:AddEvent("reputation", { faction = faction, decreased = true })
  end
end

Journal:RegisterRenderer("reputation", function(data)
  if data.tier then
    return "Reputation tier: " .. data.tier .. " with " .. (data.faction or "Unknown")
  elseif data.changes then
    -- Aggregated reputation changes from combat
    local parts = {}
    for faction, change in pairs(data.changes) do
      if change >= 0 then
        table.insert(parts, faction .. " +" .. change)
      else
        table.insert(parts, faction .. " " .. change)
      end
    end
    table.sort(parts)
    return "Reputation: " .. table.concat(parts, ", ")
  elseif data.change then
    if data.change >= 0 then
      return "Reputation with " .. (data.faction or "Unknown") .. " increased by " .. data.change
    else
      return "Reputation with " .. (data.faction or "Unknown") .. " decreased by " .. math.abs(data.change)
    end
  elseif data.amount then
    -- Legacy support for old entries
    return "Reputation with " .. (data.faction or "Unknown") .. " increased by " .. data.amount
  elseif data.decreased then
    return "Reputation with " .. (data.faction or "Unknown") .. " decreased"
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
