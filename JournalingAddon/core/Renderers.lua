local _, Journal = ...
Journal = Journal or _G.Journal or {}
Journal.Renderers = Journal.Renderers or {}

function Journal:RegisterRenderer(eventType, fn)
  if not eventType or not fn then
    return
  end
  Journal.Renderers[eventType] = fn
end

function Journal:RenderMessage(eventType, data)
  local renderer = Journal.Renderers[eventType]
  if renderer then
    return renderer(data or {})
  end
  -- Fallback for unknown types
  return eventType .. " event"
end

Journal:RegisterRenderer("system", function(data)
  local text = data.message or "System event"
  if data.note and data.note ~= "" then
    text = text .. " [note: \"" .. data.note .. "\"]"
  end
  return text
end)
