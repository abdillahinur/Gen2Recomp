local BattleEngine = {}
BattleEngine.__index = BattleEngine

local SIDE_IDS = { player = true, opponent = true }

local function otherSide(state, sideId)
  return sideId == "player" and state.opponent or state.player
end

local function actionClass(action)
  if action.kind == "switch" then return 2 end
  return 1
end

function BattleEngine.new(state, registry, options)
  options = options or {}
  if type(state) ~= "table" or type(state.emit) ~= "function" then
    error("battle engine: battle state is required", 2)
  end
  if type(registry) ~= "table" or type(registry.get) ~= "function" then
    error("battle engine: data registry is required", 2)
  end
  return setmetatable({
    state = state,
    registry = registry,
    moveExecutor = options.moveExecutor,
  }, BattleEngine)
end

function BattleEngine:_side(sideId)
  if not SIDE_IDS[sideId] then
    error("battle engine: side must be player or opponent", 3)
  end
  return self.state[sideId]
end

function BattleEngine:_normalizeAction(sideId, source)
  if type(source) ~= "table" then
    error("battle engine: action must be a table", 3)
  end
  local side = self:_side(sideId)
  if source.kind == "move" then
    local index = source.moveIndex
    if type(index) ~= "number" or index % 1 ~= 0 then
      error("battle engine: move index must be an integer", 3)
    end
    local slot = side:active().moves[index]
    if not slot then error("battle engine: move slot is unavailable", 3) end
    if slot.pp <= 0 then error("battle engine: move has no PP", 3) end
    local move = self.registry:get("moves", slot.id)
    return {
      kind = "move",
      sideId = sideId,
      moveIndex = index,
      move = move,
      priority = move.priority,
      speed = side:active().stats.speed,
    }
  elseif source.kind == "switch" then
    local index = source.partyIndex
    if type(index) ~= "number" or index % 1 ~= 0
        or not side.party[index] then
      error("battle engine: switch target is unavailable", 3)
    end
    if index == side.activeIndex then
      error("battle engine: switch target is already active", 3)
    end
    if side.party[index]:isFainted() then
      error("battle engine: switch target has fainted", 3)
    end
    return {
      kind = "switch",
      sideId = sideId,
      partyIndex = index,
      priority = 0,
      speed = side:active().stats.speed,
    }
  end
  error("battle engine: unsupported action kind " .. tostring(source.kind), 3)
end

function BattleEngine:_orderedActions()
  local player = self.state.pendingActions.player
  local opponent = self.state.pendingActions.opponent
  local function before(left, right)
    local leftClass = actionClass(left)
    local rightClass = actionClass(right)
    if leftClass ~= rightClass then return leftClass > rightClass end
    if left.priority ~= right.priority then
      return left.priority > right.priority
    end
    if left.speed ~= right.speed then return left.speed > right.speed end
    return nil
  end
  local playerFirst = before(player, opponent)
  if playerFirst == nil then
    playerFirst = self.state.rng:range(0, 1) == 0
  end
  return playerFirst
    and { player, opponent }
    or { opponent, player }
end

function BattleEngine:_execute(action)
  local side = self:_side(action.sideId)
  if action.kind == "switch" then
    local previous = side.activeIndex
    side.activeIndex = action.partyIndex
    self.state:emit("battle.switched", {
      sideId = action.sideId,
      from = previous,
      to = action.partyIndex,
    })
    return
  end
  local actor = side:active()
  if actor:isFainted() then
    self.state:emit("battle.action_skipped", {
      sideId = action.sideId,
      reason = "fainted",
    })
    return
  end
  local slot = actor.moves[action.moveIndex]
  slot.pp = slot.pp - 1
  self.state:emit("battle.move_used", {
    sideId = action.sideId,
    moveId = action.move.id,
    remainingPP = slot.pp,
  })
  if self.moveExecutor then
    self.moveExecutor(
      self.state,
      action.sideId,
      actor,
      otherSide(self.state, action.sideId):active(),
      action.move
    )
  end
end

function BattleEngine:submit(sideId, source)
  if self.state.phase ~= "command" then
    error("battle engine: battle is not accepting commands", 2)
  end
  if self.state.pendingActions[sideId] then
    error("battle engine: side already selected an action", 2)
  end
  local action = self:_normalizeAction(sideId, source)
  self.state.pendingActions[sideId] = action
  self.state:emit("battle.action_selected", {
    sideId = sideId,
    kind = action.kind,
  })
  if self.state.pendingActions.player
      and self.state.pendingActions.opponent then
    return self:resolveTurn()
  end
  return nil
end

function BattleEngine:resolveTurn()
  self.state.phase = "resolving"
  local order = self:_orderedActions()
  for _, action in ipairs(order) do self:_execute(action) end
  self.state.pendingActions = {}
  self.state.turn = self.state.turn + 1
  self.state.phase = "command"
  self.state:emit("battle.turn_complete")
  return order
end

return BattleEngine
