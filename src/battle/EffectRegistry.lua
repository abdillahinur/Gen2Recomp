local EffectRegistry = {}
EffectRegistry.__index = EffectRegistry

function EffectRegistry.new()
  return setmetatable({ handlers = {} }, EffectRegistry)
end

function EffectRegistry:register(id, handler)
  if type(id) ~= "string" or id == "" then
    error("effect registry: id is required", 2)
  end
  if type(handler) ~= "function" then
    error("effect registry: handler must be a function", 2)
  end
  if self.handlers[id] then
    error("effect registry: duplicate effect id " .. id, 2)
  end
  self.handlers[id] = handler
end

function EffectRegistry:execute(state, sideId, actor, target, move)
  local handler = self.handlers[move.effectId]
  if not handler then
    error("effect registry: unknown effect id " .. move.effectId, 2)
  end
  return handler(state, sideId, actor, target, move)
end

return EffectRegistry
