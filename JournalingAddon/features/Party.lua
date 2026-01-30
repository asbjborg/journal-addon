local _, Journal = ...
Journal = Journal or _G.Journal or {}

-- Party event state (module-level so it persists across roster updates)
local lastPartyCount = nil
local lastPartyNames = nil
local pendingInviteFrom = nil
local lastRemovedMember = nil  -- suppress duplicate "member_left" when we already logged "removed_member" from chat

-- Strip color codes from chat message (same as other features)
local function cleanMsg(msg)
  if not msg or msg == "" then return "" end
  return msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Get current party size and member names (TBC: GetNumPartyMembers, party1..party4)
local function getPartyRoster()
  local n = 0
  if GetNumPartyMembers then
    n = GetNumPartyMembers()
  end
  local names = {}
  for i = 1, n do
    local name = UnitName("party" .. i)
    if name and name ~= "" then
      -- Strip realm suffix for consistency
      name = name:match("([^%-]+)") or name
      table.insert(names, name)
    end
  end
  return n, names
end

-- Build set of names for diffing
local function nameSet(names)
  local set = {}
  for _, n in ipairs(names) do
    set[n] = true
  end
  return set
end

local function handleRosterUpdate()
  local currentCount, currentNames = getPartyRoster()
  local inParty = currentCount >= 1

  -- We had a pending invite and we're now in a party -> we accepted (check before seeding so we don't skip it)
  if pendingInviteFrom and inParty then
    Journal:AddEvent("party", {
      action = "accepted_invite",
      inviter = pendingInviteFrom,
    })
    pendingInviteFrom = nil
  end

  -- First run or just entered world: seed state without logging joins/leaves
  if lastPartyCount == nil then
    lastPartyCount = currentCount
    lastPartyNames = currentNames
    return
  end

  -- Someone joined (count increased or new name in list)
  local prevSet = nameSet(lastPartyNames or {})
  for _, name in ipairs(currentNames) do
    if not prevSet[name] then
      Journal:AddEvent("party", {
        action = "member_joined",
        name = name,
      })
    end
  end

  -- Someone left (was in previous, not in current); skip if we already logged "removed_member" for them from chat
  local currSet = nameSet(currentNames)
  for _, name in ipairs(lastPartyNames or {}) do
    if not currSet[name] then
      if name == lastRemovedMember then
        lastRemovedMember = nil
      else
        Journal:AddEvent("party", {
          action = "member_left",
          name = name,
        })
      end
    end
  end

  lastPartyCount = currentCount
  lastPartyNames = currentNames
end

-- PARTY_INVITE_REQUEST: we were invited (arg1 = inviter name in TBC)
Journal.On("PARTY_INVITE_REQUEST", function(inviterName)
  if inviterName and inviterName ~= "" then
    local name = inviterName:match("([^%-]+)") or inviterName
    pendingInviteFrom = name
    Journal:AddEvent("party", {
      action = "invited",
      inviter = name,
    })
  end
end)

-- Roster changed (TBC anniversary 20505)
Journal.On("PARTY_MEMBERS_CHANGED", handleRosterUpdate)

-- CHAT_MSG_SYSTEM: "You have invited X", "You leave the group.", "You have been removed.", "X has joined.", "X has left."
-- Use WoW global format strings when available for localization; fallback to English patterns.
Journal.On("CHAT_MSG_SYSTEM", function(msg)
  if not msg or msg == "" then return end
  local cleaned = cleanMsg(msg)

  -- "You have invited [name] to join your group." (localization: add global string pattern if needed)
  local invited = cleaned:match("^You have invited (.+) to join your group%.?$")
  if invited and invited ~= "" then
    local name = invited:match("([^%-]+)") or invited
    Journal:AddEvent("party", {
      action = "invited",
      name = name,
    })
    return
  end

  -- "You leave the group."
  if cleaned:match("^You leave the group%.?$") or cleaned:match("^You have left the group%.?$") then
    Journal:AddEvent("party", { action = "left" })
    lastPartyCount = 0
    lastPartyNames = {}
    return
  end

  -- "You have been removed from the group."
  if cleaned:match("^You have been removed from the group%.?$") then
    Journal:AddEvent("party", { action = "removed" })
    lastPartyCount = 0
    lastPartyNames = {}
    return
  end

  -- "Your group has been disbanded." (when we disband as leader)
  if cleaned:match("^Your group has been disbanded%.?$") then
    Journal:AddEvent("party", { action = "disbanded" })
    lastPartyCount = 0
    lastPartyNames = {}
    return
  end

  -- "You have removed [name] from the group." (when we remove a member)
  -- Set lastRemovedMember so roster update doesn't also log "member_left" for same person
  local removedMember = cleaned:match("^You have removed (.+) from the group%.?$")
  if removedMember and removedMember ~= "" then
    local name = removedMember:match("([^%-]+)") or removedMember
    lastRemovedMember = name
    Journal:AddEvent("party", {
      action = "removed_member",
      name = name,
    })
    return
  end

  -- member_joined / member_left are handled by roster update (PARTY_MEMBERS_CHANGED / GROUP_ROSTER_UPDATE)
  -- to avoid duplicate entries; no need to parse "X has joined" / "X has left" here
end)

-- Renderer for party events
Journal:RegisterRenderer("party", function(data)
  if not data or not data.action then
    return "Party event"
  end
  if data.action == "invited" then
    if data.inviter then
      return "Invited to party by " .. data.inviter .. "."
    end
    if data.name then
      return "Invited " .. data.name .. " to the party."
    end
    return "Party invite."
  end
  if data.action == "accepted_invite" then
    return "Accepted party invite from " .. (data.inviter or "?") .. "."
  end
  if data.action == "left" then
    return "Left the party."
  end
  if data.action == "removed" then
    return "Removed from the party."
  end
  if data.action == "disbanded" then
    return "Disbanded the party."
  end
  if data.action == "removed_member" then
    return "Removed " .. (data.name or "?") .. " from the party."
  end
  if data.action == "member_joined" then
    return (data.name or "Someone") .. " joined the party."
  end
  if data.action == "member_left" then
    return (data.name or "Someone") .. " left the party."
  end
  return "Party: " .. tostring(data.action)
end)
