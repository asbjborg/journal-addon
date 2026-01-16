local _, Journal = ...
Journal = Journal or _G.Journal or {}

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
  self:AddEvent("quest", {
    action = "turned_in",
    questID = questID,
    title = title,
    xp = xpReward,
    money = moneyReward,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
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
    end
  end
end)
