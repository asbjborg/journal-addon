local addonName, Journal = ...
Journal = Journal or {}
Journal.addonName = addonName
Journal.debug = Journal.debug or false
Journal.handlers = Journal.handlers or {}
Journal.Renderers = Journal.Renderers or {}
Journal.Util = Journal.Util or {}
_G.Journal = Journal

function Journal.On(eventType, fn)
  if not eventType or not fn then
    return
  end
  local list = Journal.handlers[eventType]
  if not list then
    list = {}
    Journal.handlers[eventType] = list
  end
  table.insert(list, fn)
end

function Journal.Emit(eventType, ...)
  local list = Journal.handlers[eventType]
  if not list then
    return
  end
  for _, fn in ipairs(list) do
    fn(...)
  end
end
