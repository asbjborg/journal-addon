local _, Journal = ...
Journal = Journal or _G.Journal or {}

function Journal:HandleFlightStart()
  if self.flightState.onTaxi then
    return
  end
  self.flightState.onTaxi = true
  if not self.flightState.originZone then
    self.flightState.originZone = GetRealZoneText()
  end
  self.flightState.startedAt = time()
  local dest = self.flightState.destinationName
  local origin = self.flightState.originName or self.flightState.originZone
  self:AddEvent("travel", {
    action = "flight_start",
    origin = origin,
    destination = dest,
    hops = self.flightState.hops,
  })
end

function Journal:CaptureTaxiOrigin()
  if not NumTaxiNodes then
    return
  end
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then
      local nodeName = TaxiNodeName(i)
      if nodeName and nodeName ~= "" then
        local location, zone = nodeName:match("^([^,]+),?%s*(.*)$")
        self.flightState.originName = location or nodeName
        if zone and zone ~= "" then
          self.flightState.originZone = zone
        end
      end
      return
    end
  end
end

function Journal:CaptureTaxiDestination(index)
  if not index or index <= 0 then
    return
  end
  local nodeName = TaxiNodeName(index)
  if not nodeName or nodeName == "" then
    return
  end
  local location, zone = nodeName:match("^([^,]+),?%s*(.*)$")
  location = location or nodeName
  self.flightState.destinationName = location
  self.flightState.destinationZone = zone
  if GetNumRoutes and GetNumRoutes(index) and GetNumRoutes(index) > 0 then
    local hops = {}
    for routeIndex = 1, GetNumRoutes(index) do
      local sourceSlot = TaxiGetNodeSlot(index, routeIndex, true)
      local destSlot = TaxiGetNodeSlot(index, routeIndex, false)
      if sourceSlot and destSlot then
        local sourceName = TaxiNodeName(sourceSlot)
        local destName = TaxiNodeName(destSlot)
        if sourceName and destName then
          local srcLoc = sourceName:match("^([^,]+)")
          local dstLoc = destName:match("^([^,]+)")
          table.insert(hops, { from = srcLoc or sourceName, to = dstLoc or destName })
        end
      end
    end
    if #hops > 0 then
      self.flightState.hops = hops
    end
  end
end

function Journal:HandleFlightEnd()
  if not self.flightState.onTaxi then
    return
  end
  self.flightState.onTaxi = false
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  self:AddEvent("travel", {
    action = "flight_end",
    zone = zone,
    subZone = subZone,
  })
  self.flightState.originZone = nil
  self.flightState.destinationName = nil
  self.flightState.destinationZone = nil
  self.flightState.originName = nil
  self.flightState.startedAt = nil
  self.flightState.hops = nil
end

function Journal:HandleZoneChanged()
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  if not zone or zone == "" then
    return
  end

  if self.lastZone and zone ~= self.lastZone then
    if not self.flightState.onTaxi then
      local fromZone = self.lastZone
      local fromSub = self.lastSubZone
      local isHearth = self.lastHearthCastAt and (time() - self.lastHearthCastAt) <= 90

      self:AddEvent("travel", {
        action = isHearth and "hearth" or "zone_change",
        zone = zone,
        subZone = subZone,
        fromZone = fromZone,
        fromSubZone = fromSub,
      })

      if isHearth then
        self.lastHearthCastAt = nil
        self.lastHearthFrom = nil
      end
    end
  end

  if not self.lastZone or zone ~= self.lastZone then
    self.lastZone = zone
  end
  self.lastSubZone = subZone
end

function Journal:HandleSubZoneChanged()
  local zone = GetRealZoneText()
  local subZone = GetSubZoneText()
  if not zone or zone == "" then
    return
  end

  -- Only track subzone changes within the same major zone
  if zone == self.lastZone and subZone and subZone ~= "" and subZone ~= self.lastSubZone then
    -- Skip if on taxi
    if self.flightState.onTaxi then
      self.lastSubZone = subZone
      return
    end

    -- Debounce: don't log if we just logged this subzone recently
    local now = time()
    self.subZoneDebounce = self.subZoneDebounce or {}
    local key = zone .. ":" .. subZone
    if self.subZoneDebounce[key] and (now - self.subZoneDebounce[key]) < 30 then
      self:DebugLog("Subzone debounced: " .. subZone .. " (seen " .. (now - self.subZoneDebounce[key]) .. "s ago)")
      self.lastSubZone = subZone
      return
    end
    self.subZoneDebounce[key] = now

    -- Clean old debounce entries (keep last 10)
    local count = 0
    for _ in pairs(self.subZoneDebounce) do count = count + 1 end
    if count > 10 then
      local oldest_key, oldest_time = nil, now
      for k, t in pairs(self.subZoneDebounce) do
        if t < oldest_time then
          oldest_key, oldest_time = k, t
        end
      end
      if oldest_key then
        self.subZoneDebounce[oldest_key] = nil
      end
    end

    self:DebugLog("Subzone change: " .. (self.lastSubZone or "?") .. " -> " .. subZone)
    self:AddEvent("travel", {
      action = "subzone_change",
      zone = zone,
      subZone = subZone,
      fromSubZone = self.lastSubZone,
    })
  end

  self.lastSubZone = subZone
end

Journal:RegisterRenderer("travel", function(data)
  if data.action == "flight_start" then
    local text = "Started flying"
    if data.destination then
      text = text .. " to " .. data.destination
    end
    if data.origin then
      text = text .. " from " .. data.origin
    end
    return text .. "."
  elseif data.action == "flight_end" then
    return "Landed in " .. (data.zone or "unknown") .. "."
  elseif data.action == "hearth" then
    local toText = data.subZone and data.subZone ~= ""
      and (data.zone .. " - " .. data.subZone) or data.zone
    local fromText = data.fromSubZone and data.fromSubZone ~= ""
      and (data.fromZone .. " - " .. data.fromSubZone) or data.fromZone
    return "Hearth to " .. (toText or "unknown") .. " from " .. (fromText or "unknown") .. "."
  elseif data.action == "subzone_change" then
    local toText = data.subZone or "unknown"
    local fromText = data.fromSubZone or "unknown"
    return "Entered " .. toText .. " (from " .. fromText .. ")."
  else
    local toText = data.subZone and data.subZone ~= ""
      and (data.zone .. " - " .. data.subZone) or data.zone
    local fromText = data.fromSubZone and data.fromSubZone ~= ""
      and (data.fromZone .. " - " .. data.fromSubZone) or data.fromZone
    return "Traveled to " .. (toText or "unknown") .. " from " .. (fromText or "unknown") .. "."
  end
end)

Journal.On("CHAT_MSG_SYSTEM", function(msg)
  if msg and msg ~= "" then
    local cleaned = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local flightDest = cleaned:match("^Taking flight to: %[(.+)%]$")
    if flightDest and flightDest ~= "" then
      Journal.flightState.destinationName = flightDest
      if not Journal.flightState.onTaxi then
        Journal:HandleFlightStart()
      end
    end
  end
end)

Journal.On("PLAYER_CONTROL_LOST", function()
  if UnitOnTaxi("player") and not Journal.flightState.onTaxi then
    if not Journal.flightState.originName then
      Journal:CaptureTaxiOrigin()
    end
    if not Journal.flightState.destinationName then
      Journal.flightState.originZone = GetRealZoneText()
    end
    Journal:HandleFlightStart()
  end
end)

Journal.On("PLAYER_CONTROL_GAINED", function()
  if Journal.flightState.onTaxi then
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, function()
        if Journal.flightState.onTaxi and not UnitOnTaxi("player") then
          Journal:HandleFlightEnd()
        end
      end)
    else
      if not UnitOnTaxi("player") then
        Journal:HandleFlightEnd()
      end
    end
  end
end)

Journal.On("ZONE_CHANGED_NEW_AREA", function()
  if Journal.flightState.onTaxi and not UnitOnTaxi("player") then
    Journal:HandleFlightEnd()
  end
  Journal:HandleZoneChanged()
end)

Journal.On("ZONE_CHANGED", function()
  Journal:HandleSubZoneChanged()
end)

Journal.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, spellName)
  if unit == "player" and spellName then
    local hearthNames = {
      "Hearthstone",
      "Innkeeper's Daughter",
      "Astral Recall",
      "Home",
    }
    for _, name in ipairs(hearthNames) do
      if spellName:find(name, 1, true) then
        Journal.lastHearthCastAt = time()
        local zone = GetRealZoneText()
        local subZone = GetSubZoneText()
        Journal.lastHearthFrom = (subZone and subZone ~= "" and (zone .. " - " .. subZone)) or zone
        break
      end
    end
  end
end)

hooksecurefunc("TakeTaxiNode", function(index)
  if not Journal.flightState.onTaxi then
    Journal:CaptureTaxiOrigin()
    Journal:CaptureTaxiDestination(index)
    Journal:HandleFlightStart()
  end
end)
