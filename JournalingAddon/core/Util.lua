local _, Journal = ...
Journal = Journal or _G.Journal or {}
Journal.Util = Journal.Util or {}

-- ISO 8601 timestamp generator (using local time, not UTC, to avoid timezone issues)
local function ISOTimestamp()
  return date("%Y-%m-%dT%H:%M:%S")
end

-- Format copper amount as "Xg Ys Zc" string
local function FormatMoney(copper)
  if not copper or copper <= 0 then
    return "0c"
  end

  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local remainingCopper = copper % 100

  local parts = {}
  if gold > 0 then
    table.insert(parts, gold .. "g")
  end
  if silver > 0 then
    table.insert(parts, silver .. "s")
  end
  if remainingCopper > 0 or #parts == 0 then
    table.insert(parts, remainingCopper .. "c")
  end

  return table.concat(parts, " ")
end

-- Simple JSON encoder for export
local function EncodeJSON(val, indent)
  indent = indent or 0
  local t = type(val)

  if val == nil then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    return tostring(val)
  elseif t == "string" then
    -- Escape special characters
    local escaped = val:gsub("\\", "\\\\")
      :gsub("\"", "\\\"")
      :gsub("\n", "\\n")
      :gsub("\r", "\\r")
      :gsub("\t", "\\t")
    return "\"" .. escaped .. "\""
  elseif t == "table" then
    -- Check if array (sequential integer keys starting at 1)
    local isArray = true
    local maxIndex = 0
    for k, _ in pairs(val) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        isArray = false
        break
      end
      if k > maxIndex then
        maxIndex = k
      end
    end
    -- Also check for gaps
    if isArray and maxIndex > 0 then
      for i = 1, maxIndex do
        if val[i] == nil then
          isArray = false
          break
        end
      end
    end

    if isArray and maxIndex > 0 then
      -- Encode as array
      local parts = {}
      for i = 1, maxIndex do
        table.insert(parts, EncodeJSON(val[i], indent))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Encode as object
      local parts = {}
      local keys = {}
      for k in pairs(val) do
        if type(k) == "string" then
          table.insert(keys, k)
        end
      end
      table.sort(keys)
      for _, k in ipairs(keys) do
        local v = val[k]
        if v ~= nil then
          table.insert(parts, EncodeJSON(k) .. ":" .. EncodeJSON(v, indent))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  return "null"
end

local function CopyTable(src)
  local dst = {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      local child = {}
      for ck, cv in pairs(v) do
        child[ck] = cv
      end
      dst[k] = child
    else
      dst[k] = v
    end
  end
  return dst
end

Journal.Util.ISOTimestamp = ISOTimestamp
Journal.Util.FormatMoney = FormatMoney
Journal.Util.EncodeJSON = EncodeJSON
Journal.Util.CopyTable = CopyTable

Journal.ISOTimestamp = ISOTimestamp
Journal.FormatMoney = FormatMoney
Journal.EncodeJSON = EncodeJSON
Journal.CopyTable = CopyTable
