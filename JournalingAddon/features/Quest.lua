local _, Journal = ...
Journal = Journal or _G.Journal or {}

local QUEST_REWARD_BUFFER_WINDOW = 2  -- Buffer events within 2 seconds of quest turn-in

function Journal:LogQuestAccepted(questLogIndex, questID)
  local title, _, _, _, _, _, _, derivedQuestID = GetQuestLogTitle(questLogIndex)
  questID = questID or derivedQuestID
  if not title or title == "" then
    title = questID and ("Quest " .. questID) or "Quest"
  end
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  self:AddEvent("quest", {
    action = "accepted",
    questID = questID,
    title = title,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
end

function Journal:LogQuestTurnedIn(questID, xpReward, moneyReward)
  local title = nil
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    title = C_QuestLog.GetTitleForQuestID(questID)
  end
  local fallbackTitle = nil
  if self.lastQuestCompleted and (time() - self.lastQuestCompleted.ts) <= 5 then
    fallbackTitle = self.lastQuestCompleted.title
  end
  if not title or title == "" or title == ("Quest " .. questID) then
    title = fallbackTitle or ("Quest " .. questID)
  end
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  
  -- Reorder quest-related events: find level/xp/reputation events that occurred recently
  local relatedEvents = {}
  local relatedIndices = {}
  local now = time()
  if self.currentSession and self.currentSession.entries then
    -- Look at last 10 entries (quest rewards typically happen within a few seconds)
    local startIndex = math.max(1, #self.currentSession.entries - 9)
    for i = #self.currentSession.entries, startIndex, -1 do
      local entry = self.currentSession.entries[i]
      -- Check if this is a quest-related event type
      if entry.type == "level" or entry.type == "xp" or entry.type == "reputation" then
        -- Check if this event was added recently (within quest reward window)
        -- Since events are added sequentially, if we see quest-related events in the last few entries,
        -- they're likely from the quest turn-in
        table.insert(relatedEvents, 1, entry)
        table.insert(relatedIndices, 1, i)
      end
    end
  end
  
  -- If we have related events to reorder, remove them first
  if #relatedEvents > 0 and self.currentSession and self.currentSession.entries then
    -- Remove related events from back to front to preserve indices
    for i = #relatedIndices, 1, -1 do
      table.remove(self.currentSession.entries, relatedIndices[i])
    end
  end
  
  -- Log quest turn-in (will be added at end, then we'll move it)
  self:AddEvent("quest", {
    action = "turned_in",
    questID = questID,
    title = title,
    xp = xpReward,
    money = moneyReward,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
  
  -- Reorder: move quest event before related events
  if #relatedEvents > 0 and self.currentSession and self.currentSession.entries then
    -- Get the quest event we just added (last entry)
    local questEvent = table.remove(self.currentSession.entries)
    
    -- Insert quest event at the position of the first related event
    local insertPos = relatedIndices[1]
    table.insert(self.currentSession.entries, insertPos, questEvent)
    
    -- Re-add related events after quest event
    for i, event in ipairs(relatedEvents) do
      table.insert(self.currentSession.entries, insertPos + i, event)
    end
    
    if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
      self:RefreshUI()
    end
  end
  
  -- Clear buffer
  self.questRewardBuffer = nil
  self.questRewardBufferStartTime = nil
  self.lastQuestCompleted = nil
end


Journal:RegisterRenderer("quest", function(data)
  local suffix = data.questID and (" (" .. data.questID .. ")") or ""
  if data.action == "accepted" then
    return "Accepted: " .. (data.title or "Quest") .. suffix
  elseif data.action == "turned_in" then
    return "Turned in: " .. (data.title or "Quest") .. suffix
  end
  return "Quest: " .. (data.title or "Unknown") .. suffix
end)

Journal.On("QUEST_ACCEPTED", function(questLogIndex, questID)
  if questLogIndex then
    Journal:LogQuestAccepted(questLogIndex, questID)
  end
  if Journal.inAggWindow then
    Journal:CloseAggWindow()
  end
end)

Journal.On("QUEST_TURNED_IN", function(questID, xpReward, moneyReward)
  if questID then
    Journal:LogQuestTurnedIn(questID, xpReward, moneyReward)
    -- Track quest turn-in time for loot aggregation exclusion
    Journal.lastQuestTurnedIn = time()
  end
  if Journal.inAggWindow then
    Journal:CloseAggWindow()
  end
end)

Journal.On("CHAT_MSG_SYSTEM", function(msg)
  if msg and msg ~= "" then
    local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local name = cleaned:match("^Quest completed: (.+)$")
      or cleaned:match("^(.+) completed%.$")
    if name and name ~= "" then
      Journal.lastQuestCompleted = { title = name, ts = time() }
      -- Start buffering quest-related events for reordering
      Journal.questRewardBuffer = {}
      Journal.questRewardBufferStartTime = time()
    end
  end
end)
