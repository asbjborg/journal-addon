local _, Journal = ...
Journal = Journal or _G.Journal or {}

function Journal:CaptureNote(note)
  if not note or note == "" then
    return
  end

  self:AddEvent("note", {
    text = note,
  })
end

function Journal:ShowNoteCaptureDialog()
  self:ShowNoteCaptureDialogWithOptions()
end

function Journal:CreateNoteCaptureDialog()
  if self.noteCaptureFrame then
    return
  end

  local frame = CreateFrame("Frame", "JournalNoteCaptureFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(500, 300)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Add Note")

  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  label:SetText("Note:")

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 50)

  local editBox = CreateFrame("EditBox", nil, scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetWidth(scrollFrame:GetWidth() - 20)
  editBox:SetAutoFocus(true)
  editBox:EnableMouse(true)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  scrollFrame:SetScrollChild(editBox)
  frame.editBox = editBox

  local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  saveButton:SetSize(100, 22)
  saveButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
  saveButton:SetText("Save")
  saveButton:SetScript("OnClick", function()
    local note = editBox:GetText()
    if note and note ~= "" then
      if frame.onSave then
        frame.onSave(note)
      else
        Journal:CaptureNote(note)
      end
    end
    frame:Hide()
  end)

  local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  cancelButton:SetSize(100, 22)
  cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
  cancelButton:SetText("Cancel")
  cancelButton:SetScript("OnClick", function()
    frame:Hide()
    if frame.onCancel then
      frame.onCancel()
    end
  end)

  self.noteCaptureFrame = frame
  frame.noteLabel = label
end

function Journal:ShowNoteCaptureDialogWithOptions(options)
  if not self.noteCaptureFrame then
    self:CreateNoteCaptureDialog()
  end
  if not self.noteCaptureFrame then
    return
  end
  options = options or {}
  local frame = self.noteCaptureFrame
  frame.onSave = options.onSave
  frame.onCancel = options.onCancel
  if frame.title and options.title then
    frame.title:SetText(options.title)
  else
    frame.title:SetText("Add Note")
  end
  if frame.noteLabel and options.label then
    frame.noteLabel:SetText(options.label)
  else
    frame.noteLabel:SetText("Note:")
  end
  frame:Show()
  frame:Raise()
  frame.editBox:SetText("")
  frame.editBox:SetFocus()
end

local function FormatShortDuration(seconds)
  if not seconds or seconds < 0 then
    return nil
  end
  if seconds >= 60 then
    return tostring(math.floor(seconds / 60)) .. "m"
  end
  return tostring(math.floor(seconds)) .. "s"
end

function Journal:AttachNoteToEvent(event, note)
  if not event or not event.data then
    return
  end
  event.data.note = note
  event.msg = self:RenderMessage(event.type, event.data)
  if self.uiFrame and self.uiFrame:IsShown() and self.RefreshUI then
    self:RefreshUI()
  end
end

function Journal:CreateNotePromptDialog()
  if self.notePromptFrame then
    return
  end
  local frame = CreateFrame("Frame", "JournalNotePromptFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(360, 140)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Add a note?")

  local message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  message:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  message:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  message:SetJustifyH("LEFT")
  message:SetText("Write a note about what you did while away?")
  frame.message = message

  local writeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  writeButton:SetSize(120, 22)
  writeButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
  writeButton:SetText("Write note")
  writeButton:SetScript("OnClick", function()
    frame:Hide()
    if frame.onWrite then
      frame.onWrite()
    end
  end)

  local skipButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  skipButton:SetSize(120, 22)
  skipButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
  skipButton:SetText("Skip")
  skipButton:SetScript("OnClick", function()
    frame:Hide()
    if frame.onSkip then
      frame.onSkip()
    end
  end)

  self.notePromptFrame = frame
end

function Journal:ShowNotePromptDialog(options)
  if not self.notePromptFrame then
    self:CreateNotePromptDialog()
  end
  if not self.notePromptFrame then
    return
  end
  options = options or {}
  local frame = self.notePromptFrame
  frame.onWrite = options.onWrite
  frame.onSkip = options.onSkip
  if frame.title and options.title then
    frame.title:SetText(options.title)
  else
    frame.title:SetText("Add a note?")
  end
  if frame.message and options.message then
    frame.message:SetText(options.message)
  else
    frame.message:SetText("Write a note about what you did while away?")
  end
  frame:Show()
  frame:Raise()
end

function Journal:MaybePromptAwayNote(event, reason, durationSeconds)
  if not event then
    return
  end
  local minutes = durationSeconds and (durationSeconds / 60) or 0
  local thresholdMinutes = nil
  if reason == "login" then
    thresholdMinutes = self:GetSetting("loginNoteMinutes", 30)
  else
    thresholdMinutes = self:GetSetting("afkNoteMinutes", 10)
  end
  if not thresholdMinutes or minutes < thresholdMinutes then
    return
  end
  local durationText = FormatShortDuration(durationSeconds)
  local baseMessage = reason == "login"
    and "Write a note about what you did while away?"
    or "Write a note about your break?"
  if durationText then
    baseMessage = baseMessage .. " (" .. durationText .. ")"
  end
  local title = reason == "login" and "Logged in - Add Note" or "Back - Add Note"
  self:ShowNotePromptDialog({
    title = title,
    message = baseMessage,
    onWrite = function()
      self:ShowNoteCaptureDialogWithOptions({
        title = title,
        label = "Note:",
        onSave = function(note)
          self:AttachNoteToEvent(event, note)
        end,
      })
    end,
  })
end

Journal:RegisterRenderer("note", function(data)
  return "Note: " .. (data.text or data.note or "")
end)
