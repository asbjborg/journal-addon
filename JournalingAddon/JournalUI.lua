local addonName, Journal = ...
Journal = Journal or _G.Journal or {}
_G.Journal = Journal

local function FormatSessionLabel(session)
  if not session then
    return "No sessions"
  end
  local who = session.characterKey and (session.characterKey .. " ") or ""
  local startText = date("%Y-%m-%d %H:%M", session.startTime)
  local endText = session.endTime and date("%H:%M", session.endTime) or "current"
  return who .. startText .. " - " .. endText
end

function Journal:InitUI()
  if self.uiFrame then
    return
  end

  local frame = CreateFrame("Frame", "JournalFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(520, 400)
  frame:SetPoint("CENTER")
  frame:Hide()

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Journal")

  local dropdown = CreateFrame("Frame", "JournalSessionDropdown", frame, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, -28)
  UIDropDownMenu_SetWidth(dropdown, 240)
  UIDropDownMenu_SetText(dropdown, "Current session")
  frame.sessionDropdown = dropdown

  local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  exportButton:SetSize(80, 22)
  exportButton:SetPoint("LEFT", dropdown, "RIGHT", 10, 0)
  exportButton:SetText("Export")
  exportButton:SetScript("OnClick", function()
    Journal:ExportSession()
  end)
  frame.exportButton = exportButton

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -70)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(1, 1)
  scrollFrame:SetScrollChild(content)
  frame.content = content
  frame.scrollFrame = scrollFrame
  frame.entryLines = {}

  local function UpdateContentSize()
    local width = scrollFrame:GetWidth() or 1
    content:SetWidth(width)
  end

  scrollFrame:SetScript("OnSizeChanged", UpdateContentSize)
  UpdateContentSize()

  self.uiFrame = frame
end

function Journal:UpdateSessionDropdown()
  if not self.uiFrame then
    return
  end
  local dropdown = self.uiFrame.sessionDropdown
  UIDropDownMenu_Initialize(dropdown, function(_, level)
    local info = UIDropDownMenu_CreateInfo()
    for i, session in ipairs(self.db.sessions) do
      info.text = FormatSessionLabel(session)
      info.func = function()
        self.uiFrame.selectedSessionIndex = i
        UIDropDownMenu_SetSelectedID(dropdown, i)
        self:RefreshUI()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

function Journal:RefreshUI()
  if not self.uiFrame or not self.uiFrame:IsShown() then
    return
  end

  if not self.db and JournalDB then
    self.db = JournalDB
  end

  local sessions = self.db and self.db.sessions or {}
  if #sessions == 0 then
    UIDropDownMenu_SetText(self.uiFrame.sessionDropdown, "No sessions")
    for _, line in ipairs(self.uiFrame.entryLines) do
      line:Hide()
    end
    self.uiFrame.content:SetHeight(1)
    if self.debug then
      self:DebugLog("RefreshUI: no sessions")
    end
    return
  end

  if not self.uiFrame.selectedSessionIndex or self.uiFrame.selectedSessionIndex > #sessions then
    self.uiFrame.selectedSessionIndex = #sessions
  end

  self:UpdateSessionDropdown()
  UIDropDownMenu_SetSelectedID(self.uiFrame.sessionDropdown, self.uiFrame.selectedSessionIndex)

  local session = sessions[self.uiFrame.selectedSessionIndex]
  UIDropDownMenu_SetText(self.uiFrame.sessionDropdown, FormatSessionLabel(session))

  local entries = session.entries or {}
  if self.debug then
    self:DebugLog("RefreshUI: sessions=" .. #sessions .. " entries=" .. #entries)
  end
  local lineHeight = 16
  local contentWidth = (self.uiFrame.content:GetWidth() or 1) - 4

  for i, entry in ipairs(entries) do
    local line = self.uiFrame.entryLines[i]
    if not line then
      line = self.uiFrame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      self.uiFrame.entryLines[i] = line
      line:SetPoint("TOPLEFT", self.uiFrame.content, "TOPLEFT", 0, -((i - 1) * lineHeight))
      line:SetPoint("TOPRIGHT", self.uiFrame.content, "TOPRIGHT", 0, -((i - 1) * lineHeight))
      line:SetJustifyH("LEFT")
      line:SetWordWrap(true)
    end
    line:SetWidth(contentWidth)
    local timeText = date("%H:%M:%S", entry.ts)
    line:SetText(timeText .. "  " .. entry.text)
    line:Show()
  end

  for i = #entries + 1, #self.uiFrame.entryLines do
    self.uiFrame.entryLines[i]:Hide()
  end

  self.uiFrame.content:SetHeight(math.max(1, #entries * lineHeight))
end

function Journal:ExportSession()
  if not self.db and JournalDB then
    self.db = JournalDB
  end

  local sessions = self.db and self.db.sessions or {}
  if #sessions == 0 then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r No sessions to export.")
    end
    return
  end

  local sessionIndex = self.uiFrame and self.uiFrame.selectedSessionIndex or #sessions
  if sessionIndex > #sessions then
    sessionIndex = #sessions
  end

  local session = sessions[sessionIndex]
  if not session or not session.entries or #session.entries == 0 then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r Selected session has no entries.")
    end
    return
  end

  local lines = {}
  local who = session.characterKey and (session.characterKey .. " - ") or ""
  local startText = date("%Y-%m-%d %H:%M", session.startTime)
  local endText = session.endTime and date("%H:%M", session.endTime) or "current"
  table.insert(lines, who .. startText .. " - " .. endText)
  table.insert(lines, "")

  for _, entry in ipairs(session.entries) do
    local timeText = date("%H:%M:%S", entry.ts)
    table.insert(lines, timeText .. "  " .. entry.text)
  end

  local text = table.concat(lines, "\n")
  self:ShowExportDialog(text)
end

function Journal:ShowExportDialog(text)
  if self.exportFrame then
    self.exportFrame:Show()
    self.exportFrame:Raise()
    self.exportFrame.editBox:SetText(text)
    self.exportFrame.editBox:HighlightText()
    self.exportFrame.editBox:SetFocus()
    return
  end

  local frame = CreateFrame("Frame", "JournalExportFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(600, 500)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
  frame.title:SetText("Export Session")

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)

  local editBox = CreateFrame("EditBox", nil, scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetWidth(scrollFrame:GetWidth() - 20)
  editBox:SetAutoFocus(true)
  editBox:EnableMouse(true)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  editBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  scrollFrame:SetScrollChild(editBox)
  frame.editBox = editBox

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  closeButton:SetSize(100, 22)
  closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
  closeButton:SetText("Close")
  closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  editBox:SetText(text)
  editBox:HighlightText()
  editBox:SetFocus()

  self.exportFrame = frame
end

function Journal:ToggleUI()
  if not self.uiFrame then
    self:InitUI()
  end
  if self.uiFrame:IsShown() then
    self.uiFrame:Hide()
  else
    self.uiFrame:Show()
    self:RefreshUI()
  end
end

SLASH_JOURNAL1 = "/journal"
SlashCmdList["JOURNAL"] = function(msg)
  local arg = strlower((string.gsub(msg or "", "^%s*(.-)%s*$", "%1")))
  if arg == "debug" then
    Journal.debug = not Journal.debug
    local state = Journal.debug and "on" or "off"
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r debug " .. state)
    end
    return
  elseif arg == "capture" or arg == "capture-target" then
    Journal:ShowTargetCaptureDialog()
    return
  end
  Journal:ToggleUI()
end
