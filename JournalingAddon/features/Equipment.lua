local _, Journal = ...
Journal = Journal or _G.Journal or {}

local slotDefinitions = {
  { name = "HeadSlot", label = "Head" },
  { name = "NeckSlot", label = "Neck" },
  { name = "ShoulderSlot", label = "Shoulder" },
  { name = "BackSlot", label = "Back" },
  { name = "ChestSlot", label = "Chest" },
  { name = "ShirtSlot", label = "Shirt" },
  { name = "TabardSlot", label = "Tabard" },
  { name = "WristSlot", label = "Wrist" },
  { name = "HandsSlot", label = "Hands" },
  { name = "WaistSlot", label = "Waist" },
  { name = "LegsSlot", label = "Legs" },
  { name = "FeetSlot", label = "Feet" },
  { name = "Finger0Slot", label = "Finger 1" },
  { name = "Finger1Slot", label = "Finger 2" },
  { name = "Trinket0Slot", label = "Trinket 1" },
  { name = "Trinket1Slot", label = "Trinket 2" },
  { name = "MainHandSlot", label = "Main Hand" },
  { name = "SecondaryHandSlot", label = "Off Hand" },
  { name = "RangedSlot", label = "Ranged" },
  { name = "AmmoSlot", label = "Ammo" },
}

local slotLabelsById = {}

local function BuildSlotLabelMap()
  if next(slotLabelsById) then
    return
  end
  local getInventorySlotInfo = rawget(_G, "GetInventorySlotInfo")
  if not getInventorySlotInfo then
    return
  end
  for _, slot in ipairs(slotDefinitions) do
    local slotId = getInventorySlotInfo(slot.name)
    if slotId then
      slotLabelsById[slotId] = slot.label
    end
  end
end

function Journal:GetEquipSlotLabel(slotId)
  BuildSlotLabelMap()
  return slotLabelsById[slotId] or ("Slot " .. tostring(slotId))
end

function Journal:InitEquipState()
  BuildSlotLabelMap()
  self.equipState = self.equipState or {}
  self.equipInitRetryDone = nil
  for slotId, _ in pairs(slotLabelsById) do
    self.equipState[slotId] = GetInventoryItemLink("player", slotId)
  end

  local missingSlots = {}
  for slotId, link in pairs(self.equipState) do
    if not link or link == "" or link == "[]" then
      table.insert(missingSlots, slotId)
    end
  end

  if #missingSlots > 0 and C_Timer and C_Timer.After then
    C_Timer.After(0.5, function()
      if Journal.equipInitRetryDone then
        return
      end
      Journal.equipInitRetryDone = true
      for _, slotId in ipairs(missingSlots) do
        Journal.equipState[slotId] = GetInventoryItemLink("player", slotId)
      end
    end)
  end
end

Journal.On("PLAYER_LOGIN", function()
  Journal:InitEquipState()
end)

Journal.On("PLAYER_EQUIPMENT_CHANGED", function(slotId, hasItem)
  if not slotId then
    return
  end
  Journal.equipState = Journal.equipState or {}
  if not next(Journal.equipState) then
    Journal:InitEquipState()
  end
  local newLink = GetInventoryItemLink("player", slotId)
  local oldLink = Journal.equipState[slotId]
  if newLink == oldLink then
    return
  end
  if newLink then
    local data = {
      item = newLink,
      slot = Journal:GetEquipSlotLabel(slotId),
    }
    if oldLink and oldLink ~= "" and oldLink ~= "[]" then
      data.replaced = oldLink
    end
    Journal:AddEvent("equip", data)
  end
  Journal.equipState[slotId] = newLink
end)

Journal:RegisterRenderer("equip", function(data)
  local text = "Equipped: " .. (data.item or "Unknown item")
  if data.slot then
    text = text .. " (slot: " .. data.slot .. ")"
  end
  if data.replaced and data.replaced ~= "" and data.replaced ~= "[]" then
    text = text .. " (replaced " .. data.replaced .. ")"
  end
  return text
end)
