local BattleSceneState = require("src.states.BattleSceneState")

local BattleBridge = {}
BattleBridge.__index = BattleBridge

function BattleBridge.new(stateStack, factory, options)
  if type(stateStack) ~= "table"
      or type(stateStack.push) ~= "function"
      or type(stateStack.pop) ~= "function" then
    error("battle bridge requires a state stack", 2)
  end
  if type(factory) ~= "table"
      or type(factory.create) ~= "function"
      or type(factory.commit) ~= "function" then
    error("battle bridge requires a request factory", 2)
  end
  options = options or {}
  return setmetatable({
    states = stateStack,
    factory = factory,
    items = options.items or {},
    active = nil,
  }, BattleBridge)
end

function BattleBridge:start(request, resolve)
  if self.active then
    error("battle bridge: a battle is already active", 2)
  end
  if type(resolve) ~= "function" then
    error("battle bridge: result callback is required", 2)
  end
  local session = self.factory:create(request)
  local bridge = self
  local scene = BattleSceneState.new(session, {
    items = self.items,
    onComplete = function()
      local result = bridge.factory:commit(session)
      bridge.active = nil
      bridge.states:pop()
      resolve(result)
    end,
  })
  self.active = {
    request = request,
    session = session,
    scene = scene,
  }
  self.states:push(scene)
  return scene
end

return BattleBridge
