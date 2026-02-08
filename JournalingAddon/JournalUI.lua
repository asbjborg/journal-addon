local addonName, Journal = ...
Journal = Journal or _G.Journal or {}
_G.Journal = Journal

-- Parse ISO 8601 timestamp to Unix time (for display formatting)
local function ParseISOTimestamp(isoStr)
  if type(isoStr) == "number" then
    return isoStr  -- Already Unix timestamp (legacy)
  end
  if type(isoStr) ~= "string" then
    return time()
  end
  -- Parse "2026-01-15T19:16:12" or "2026-01-15T19:16:12Z" format
  local year, month, day, hour, min, sec = isoStr:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if year then
    return time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour),
      min = tonumber(min),
      sec = tonumber(sec),
    })
  end
  return time()
end

-- Get display text from entry (handles both old and new formats)
local function GetEntryText(entry)
  return entry.msg or entry.text or ""
end

-- Get timestamp from entry (handles both formats)
local function GetEntryTimestamp(entry)
  return ParseISOTimestamp(entry.ts)
end

-- Return entries sorted by (ts, seq) for chronological order (same as addon UI)
local function GetSortedEntries(entries)
  local sorted = {}
  for i, entry in ipairs(entries) do
    table.insert(sorted, entry)
  end
  table.sort(sorted, function(a, b)
    local tsA = GetEntryTimestamp(a)
    local tsB = GetEntryTimestamp(b)
    if tsA ~= tsB then
      return tsA < tsB
    end
    local seqA = a.seq or 0
    local seqB = b.seq or 0
    return seqA < seqB
  end)
  return sorted
end

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
  local function getAddonVersion()
    local name = addonName or "JournalingAddon"
    local cAddOns = rawget(_G, "C_AddOns")
    local cGetMeta = cAddOns and cAddOns.GetAddOnMetadata
    local version = cGetMeta and cGetMeta(name, "Version") or nil
    if not version or version == "" then
      local legacyGetMeta = rawget(_G, "GetAddOnMetadata")
      version = legacyGetMeta and legacyGetMeta(name, "Version") or nil
    end
    if (not version or version == "") and name ~= "JournalingAddon" then
      local legacyGetMeta = rawget(_G, "GetAddOnMetadata")
      version = legacyGetMeta and legacyGetMeta("JournalingAddon", "Version") or version
    end
    return version
  end
  local version = getAddonVersion()
  local titleText = "Journal"
  if version and version ~= "" then
    titleText = "Journal (v." .. version .. ")"
  end
  frame.title:SetText(titleText)

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

  local jsonExportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  jsonExportButton:SetSize(80, 22)
  jsonExportButton:SetPoint("LEFT", exportButton, "RIGHT", 4, 0)
  jsonExportButton:SetText("JSON")
  jsonExportButton:SetScript("OnClick", function()
    Journal:ExportSessionJSON()
  end)
  frame.jsonExportButton = jsonExportButton

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
    local currentSession = self.currentSession
    if currentSession then
      for i, session in ipairs(sessions) do
        if session == currentSession then
          self.uiFrame.selectedSessionIndex = i
          break
        end
      end
    end
    if not self.uiFrame.selectedSessionIndex or self.uiFrame.selectedSessionIndex > #sessions then
      self.uiFrame.selectedSessionIndex = #sessions
    end
  end

  self:UpdateSessionDropdown()
  UIDropDownMenu_SetSelectedID(self.uiFrame.sessionDropdown, self.uiFrame.selectedSessionIndex)

  local session = sessions[self.uiFrame.selectedSessionIndex]
  UIDropDownMenu_SetText(self.uiFrame.sessionDropdown, FormatSessionLabel(session))

  local entries = session.entries or {}
  if self.debug then
    self:DebugLog("RefreshUI: sessions=" .. #sessions .. " entries=" .. #entries)
  end

  local sortedEntries = GetSortedEntries(entries)

  local contentWidth = (self.uiFrame.content:GetWidth() or 1) - 4
  local entrySpacing = 4

  local currentY = 0
  for i, entry in ipairs(sortedEntries) do
    local line = self.uiFrame.entryLines[i]
    if not line then
      line = self.uiFrame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      self.uiFrame.entryLines[i] = line
      line:SetJustifyH("LEFT")
      line:SetWordWrap(true)
    end
    line:SetWidth(contentWidth)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", self.uiFrame.content, "TOPLEFT", 0, -currentY)
    line:SetPoint("TOPRIGHT", self.uiFrame.content, "TOPRIGHT", 0, -currentY)
    local timestamp = GetEntryTimestamp(entry)
    local timeText = date("%H:%M:%S", timestamp)
    local displayText = GetEntryText(entry)
    line:SetText(timeText .. "  " .. displayText)
    line:Show()
    
    local lineHeight = line:GetHeight() or 16
    currentY = currentY + lineHeight + entrySpacing
  end

  for i = #entries + 1, #self.uiFrame.entryLines do
    self.uiFrame.entryLines[i]:Hide()
  end

  self.uiFrame.content:SetHeight(math.max(1, currentY))
  
  -- Auto-scroll to bottom (with delay to ensure layout is complete)
  local scrollFrame = self.uiFrame.scrollFrame
  if scrollFrame then
    local function ScrollToBottom()
      local maxScroll = scrollFrame:GetVerticalScrollRange()
      if maxScroll and maxScroll > 0 then
        scrollFrame:SetVerticalScroll(maxScroll)
      end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0.1, ScrollToBottom)
    else
      ScrollToBottom()
    end
  end
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

  for _, entry in ipairs(GetSortedEntries(session.entries)) do
    local timestamp = GetEntryTimestamp(entry)
    local timeText = date("%H:%M:%S", timestamp)
    local displayText = GetEntryText(entry)
    table.insert(lines, timeText .. "  " .. displayText)
  end

  local text = table.concat(lines, "\n")
  self:ShowExportDialog(text, "text")
end

function Journal:ExportSessionJSON()
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

  -- Export as NDJSON (one JSON object per line)
  local lines = {}
  for _, entry in ipairs(GetSortedEntries(session.entries)) do
    -- Build clean export object with only the event fields
    local exportEntry = {
      v = entry.v or 1,
      ts = entry.ts,
      type = entry.type,
      msg = entry.msg or entry.text,
      data = entry.data or entry.meta or {},
    }
    table.insert(lines, self.EncodeJSON(exportEntry))
  end

  local text = table.concat(lines, "\n")
  self:ShowExportDialog(text, "json")
end

function Journal:ShowExportDialog(text, exportType)
  local title = exportType == "json" and "Export Session (NDJSON)" or "Export Session"
  
  if self.exportFrame then
    self.exportFrame.title:SetText(title)
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
  frame.title:SetText(title)

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
  elseif arg == "note" then
    Journal:ShowNoteCaptureDialog()
    return
  elseif arg == "undo" then
    -- Delete last entry
    local removed = Journal:RemoveLastEntry()
    if removed then
      local msg = removed.msg or removed.text or "entry"
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r Removed: " .. msg:sub(1, 50))
      end
      if Journal.uiFrame and Journal.uiFrame:IsShown() then
        Journal:RefreshUI()
      end
    else
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r No entries to remove.")
      end
    end
    return
  elseif arg == "clear" then
    -- Clear current session entries
    local count = Journal:ClearCurrentSession()
    -- Reset any in-flight activity chunk to avoid re-flushing cleared entries
    if Journal.idleTimer then
      Journal.idleTimer:Cancel()
      Journal.idleTimer = nil
    end
    if Journal.hardCapTimer then
      Journal.hardCapTimer:Cancel()
      Journal.hardCapTimer = nil
    end
    if Journal.ResetActivityChunk then
      Journal:ResetActivityChunk()
    end
    -- Add a system marker entry after clear
    Journal:AddEvent("system", { message = "Entries cleared. Starting new session." })
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r Cleared " .. count .. " entries from current session.")
    end
    if Journal.uiFrame and Journal.uiFrame:IsShown() then
      Journal:RefreshUI()
    end
    return
  elseif arg == "reset" then
    -- Start fresh session (ends current, starts new)
    Journal:StartNewSession("Entries cleared. Starting new session.")
    if Journal.uiFrame then
      local sessions = Journal.db and Journal.db.sessions or {}
      Journal.uiFrame.selectedSessionIndex = #sessions
    end
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r New session started.")
    end
    if Journal.uiFrame and Journal.uiFrame:IsShown() then
      Journal:RefreshUI()
    end
    return
  elseif arg == "wipe" then
    -- Wipe all data and start fresh session
    Journal:WipeAllData()
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r Journal data wiped.")
    end
    if Journal.uiFrame and Journal.uiFrame:IsShown() then
      Journal:RefreshUI()
    end
    return
  elseif arg == "help" then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal commands:|r")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal - Toggle UI")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal capture - Screenshot + note dialog")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal note - Add a note")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal undo - Remove last entry")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal clear - Clear current session")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal reset - Start new session")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal debug - Toggle debug mode")
      DEFAULT_CHAT_FRAME:AddMessage("  /journal wipe - Wipe all journal data")
    end
    return
  end
  Journal:ToggleUI()
end
