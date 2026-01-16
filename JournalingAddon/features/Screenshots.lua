local _, Journal = ...
Journal = Journal or _G.Journal or {}

function Journal:GetScreenshotName()
  local now = date("*t")
  local month = string.format("%02d", now.month)
  local day = string.format("%02d", now.day)
  local year = string.format("%02d", now.year % 100)
  local hour = string.format("%02d", now.hour)
  local min = string.format("%02d", now.min)
  local sec = string.format("%02d", now.sec)
  return "WoWScrnShot_" .. month .. day .. year .. "_" .. hour .. min .. sec .. ".jpg"
end

function Journal:CaptureTarget(note)
  local screenshotName = self.pendingScreenshotName
  self.pendingScreenshotName = nil
  local hasTarget = self.pendingHasTarget
  self.pendingHasTarget = nil

  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()

  if hasTarget and UnitExists("target") then
    local name = UnitName("target")
    if name and name ~= "" then
      local level = UnitLevel("target")
      if level and level <= 0 then
        level = nil
      end

      local reaction = UnitReaction("player", "target")
      local reactionText = nil
      if reaction then
        if reaction >= 5 then
          reactionText = "friendly"
        elseif reaction >= 4 then
          reactionText = "neutral"
        else
          reactionText = "hostile"
        end
      end

      local race = UnitRace("target")
      local class = UnitClass("target")

      -- Target capture - all in one screenshot event
      self:AddEvent("screenshot", {
        action = "capture_target",
        filename = screenshotName,
        note = (note and note ~= "") and note or nil,
        zone = zone,
        subZone = (subZone and subZone ~= "") and subZone or nil,
        target = {
          name = name,
          level = level,
          reaction = reactionText,
          race = (race and race ~= "") and race or nil,
          class = (class and class ~= "") and class or nil,
        },
      })
      return
    end
  end

  -- Scene capture (no target)
  self:AddEvent("screenshot", {
    action = "capture_scene",
    filename = screenshotName,
    note = (note and note ~= "") and note or nil,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
end

function Journal:ShowTargetCaptureDialog()
  self.pendingScreenshotName = self:GetScreenshotName()
  self.pendingHasTarget = UnitExists("target")

  if Screenshot then
    Screenshot()
  end

  local function ShowDialog()
    if not Journal.targetCaptureFrame then
      Journal:CreateTargetCaptureDialog()
    end
    if Journal.targetCaptureFrame then
      Journal.targetCaptureFrame:Show()
      Journal.targetCaptureFrame:Raise()
      Journal.targetCaptureFrame.editBox:SetText("")
      Journal.targetCaptureFrame.editBox:SetFocus()
    end
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(2.5, ShowDialog)
  else
    ShowDialog()
  end
end

function Journal:CreateTargetCaptureDialog()
  if self.targetCaptureFrame then
    return
  end

  local frame = CreateFrame("Frame", "JournalTargetCaptureFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(400, 120)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Capture - Add Note")

  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  label:SetText("Note (optional):")

  local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  editBox:SetSize(360, 32)
  editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  editBox:SetAutoFocus(true)
  editBox:SetScript("OnEnterPressed", function(self)
    local note = self:GetText()
    Journal:CaptureTarget(note)
    frame:Hide()
  end)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  frame.editBox = editBox

  local captureButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  captureButton:SetSize(100, 22)
  captureButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
  captureButton:SetText("Capture")
  captureButton:SetScript("OnClick", function()
    local note = editBox:GetText()
    Journal:CaptureTarget(note)
    frame:Hide()
  end)

  local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  cancelButton:SetSize(100, 22)
  cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
  cancelButton:SetText("Cancel")
  cancelButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  self.targetCaptureFrame = frame
end

Journal:RegisterRenderer("screenshot", function(data)
  local action = data.action or "manual"

  if action == "capture_target" and data.target then
    -- Target capture: "Spotted: Name (lvl X) [reaction] screenshot=..."
    local t = data.target
    local parts = { "Spotted: " .. (t.name or "Unknown") }
    if t.level then
      table.insert(parts, "(lvl " .. t.level .. ")")
    end
    if t.reaction then
      table.insert(parts, "[" .. t.reaction .. "]")
    end
    if t.race then
      table.insert(parts, t.race)
    end
    if t.class then
      table.insert(parts, t.class)
    end
    local text = table.concat(parts, " ")
    if data.note and data.note ~= "" then
      text = text .. " note=\"" .. data.note .. "\""
    end
    if data.filename then
      text = text .. " screenshot=" .. data.filename
    end
    return text
  elseif action == "capture_scene" then
    -- Scene capture: "Scene: note=\"...\" screenshot=..."
    local text = "Scene:"
    if data.note and data.note ~= "" then
      text = text .. " note=\"" .. data.note .. "\""
    end
    if data.filename then
      text = text .. " screenshot=" .. data.filename
    end
    return text
  else
    -- Manual screenshot: "Screenshot: filename"
    return "Screenshot: " .. (data.filename or "unknown")
  end
end)

Journal.On("SCREENSHOT_SUCCEEDED", function()
  -- Skip if we're in a pending capture (will be handled by CaptureTarget)
  if Journal.pendingScreenshotName then
    return
  end
  local screenshotName = Journal:GetScreenshotName()
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  Journal:AddEvent("screenshot", {
    action = "manual",
    filename = screenshotName,
    zone = zone,
    subZone = (subZone and subZone ~= "") and subZone or nil,
  })
end)
