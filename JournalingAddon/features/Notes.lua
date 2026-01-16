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
  if not self.noteCaptureFrame then
    self:CreateNoteCaptureDialog()
  end
  if self.noteCaptureFrame then
    self.noteCaptureFrame:Show()
    self.noteCaptureFrame:Raise()
    self.noteCaptureFrame.editBox:SetText("")
    self.noteCaptureFrame.editBox:SetFocus()
  end
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
      Journal:CaptureNote(note)
    end
    frame:Hide()
  end)

  local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  cancelButton:SetSize(100, 22)
  cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
  cancelButton:SetText("Cancel")
  cancelButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  self.noteCaptureFrame = frame
end

Journal:RegisterRenderer("note", function(data)
  return "Note: " .. (data.text or data.note or "")
end)
