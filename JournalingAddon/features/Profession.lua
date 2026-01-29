local _, Journal = ...
Journal = Journal or _G.Journal or {}

local SKILL_AGG_WINDOW = 10  -- 10 seconds rolling window for skill ups

function Journal:ResetSkillAgg()
  self.skillAgg = {
    skill = nil,
    startLevel = nil,
    endLevel = nil,
    startTime = nil,
  }
end

function Journal:StartSkillAggWindow(skill, level)
  -- Initialize skill aggregation if not already started or if different skill
  if not self.skillAgg or self.skillAgg.skill ~= skill then
    self:ResetSkillAgg()
    self.skillAgg.skill = skill
    -- Use previous chunk's end level as start if same skill and level increased (continuous range)
    local lastEnd = self.lastSkillChunkEnd and self.lastSkillChunkEnd[skill]
    if lastEnd and level > lastEnd then
      self.skillAgg.startLevel = lastEnd
    else
      self.skillAgg.startLevel = level
    end
    self.skillAgg.startTime = time()
  end
  
  -- Update end level
  self.skillAgg.endLevel = level
  
  -- Cancel existing timer if any
  if self.skillAggTimer then
    self.skillAggTimer:Cancel()
    self.skillAggTimer = nil
  end
  
  -- Start 10-second timer to flush
  if C_Timer and C_Timer.NewTimer then
    self.skillAggTimer = C_Timer.NewTimer(SKILL_AGG_WINDOW, function()
      Journal:CloseSkillAggWindow()
    end)
  else
    -- Fallback: flush immediately if no timer available
    self:CloseSkillAggWindow()
  end
end

function Journal:CloseSkillAggWindow()
  if self.skillAggTimer then
    self.skillAggTimer:Cancel()
    self.skillAggTimer = nil
  end
  
  if self.skillAgg and self.skillAgg.skill and self.skillAgg.startTime then
    local startLevel = self.skillAgg.startLevel
    local endLevel = self.skillAgg.endLevel
    local duration = time() - self.skillAgg.startTime
    
    if startLevel and endLevel and startLevel ~= endLevel then
      -- Multiple skill ups - show range
      self:AddEvent("profession", {
        skill = self.skillAgg.skill,
        startLevel = startLevel,
        endLevel = endLevel,
        duration = duration,
      })
    elseif endLevel then
      -- Single skill up (shouldn't happen, but handle it)
      self:AddEvent("profession", {
        skill = self.skillAgg.skill,
        level = endLevel,
      })
    end
    -- Persist end level per skill so next chunk can show continuous range (e.g. 8-12)
    if not self.lastSkillChunkEnd then
      self.lastSkillChunkEnd = {}
    end
    self.lastSkillChunkEnd[self.skillAgg.skill] = endLevel
  end
  
  self:ResetSkillAgg()
end

Journal:RegisterRenderer("profession", function(data)
  if data.startLevel and data.endLevel and data.startLevel ~= data.endLevel then
    -- Aggregated skill ups - show range
    local text = (data.skill or "Unknown") .. " skill increased from " .. data.startLevel .. "-" .. data.endLevel
    if data.duration and data.duration > 0 then
      text = text .. " (over " .. data.duration .. "s)"
    end
    return text
  else
    -- Single skill up
    return (data.skill or "Unknown") .. " skill increased to " .. (data.level or "?")
  end
end)

Journal.On("CHAT_MSG_SKILL", function(msg)
  if not msg or msg == "" then
    return
  end

  local skill, level = msg:match("Your skill in (.+) has increased to (%d+)")
  if skill and level then
    level = tonumber(level)
    Journal:DebugLog("Skill up: " .. skill .. " -> " .. level)
    
    -- Start or extend skill aggregation window
    Journal:StartSkillAggWindow(skill, level)
  end
end)
