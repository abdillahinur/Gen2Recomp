local ScriptRunner = require("src.script.ScriptRunner")

local ActorSystem = {}
ActorSystem.__index = ActorSystem

local DIRECTIONS = {
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
}

local function fail(message, level)
  error("actor system: " .. message, level or 3)
end

local function requireDirection(direction)
  if not DIRECTIONS[direction] then
    fail("invalid direction " .. tostring(direction), 3)
  end
end

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values or {}) do result[index] = value end
  return result
end

function ActorSystem.new(world)
  local self = setmetatable({
    world = world,
    bindings = {
      ["common.actor.player"] = {
        entity = world.player,
        player = true,
      },
    },
    bindingOrder = { "common.actor.player" },
    motions = {},
    motionResults = {},
    followers = {},
  }, ActorSystem)
  return self
end

function ActorSystem:bind(id, mapId, objectId)
  if self.bindings[id] then fail("actor is already bound: " .. id, 2) end
  local object = self.world:getObject(mapId, objectId)
  if not object then
    fail(("map %s has no object %s"):format(mapId, tostring(objectId)), 2)
  end
  self.bindings[id] = {
    entity = object,
    mapId = mapId,
    player = false,
  }
  self.bindingOrder[#self.bindingOrder + 1] = id
  return object
end

function ActorSystem:binding(id)
  local binding = self.bindings[id]
  if not binding then fail("unknown actor " .. tostring(id), 2) end
  return binding
end

function ActorSystem:entity(id)
  return self:binding(id).entity
end

function ActorSystem:isActive(id)
  local binding = self:binding(id)
  return binding.player or binding.mapId == self.world.currentMapId
end

function ActorSystem:isControlled(id)
  return self.motions[id] ~= nil
end

function ActorSystem:face(id, direction)
  requireDirection(direction)
  local actor = self:entity(id)
  actor.facing = direction
end

function ActorSystem:state(id)
  local binding = self:binding(id)
  local actor = binding.entity
  return {
    x = actor.x,
    y = actor.y,
    facing = actor.facing,
    mapId = binding.player and self.world.currentMapId or binding.mapId,
    visible = binding.player or actor.visible,
  }
end

function ActorSystem:setVisible(id, visible)
  local binding = self:binding(id)
  if binding.player then
    fail("the player cannot be hidden as a map object", 2)
  end
  binding.entity.visible = visible == true
end

function ActorSystem:place(id, x, y, direction)
  local binding = self:binding(id)
  if binding.player then
    fail("use a map transition to place the player", 2)
  end
  local map = self.world.repository:getMap(binding.mapId)
  if type(x) ~= "number" or type(y) ~= "number"
      or x % 1 ~= 0 or y % 1 ~= 0
      or x < 0 or y < 0
      or x >= map.widthCells or y >= map.heightCells then
    fail("object placement is outside its map", 2)
  end
  if direction ~= nil then requireDirection(direction) end
  local actor = binding.entity
  actor.x = x
  actor.y = y
  actor.pixelX = x * 16
  actor.pixelY = y * 16
  actor.moving = nil
  actor.facing = direction or actor.facing
end

function ActorSystem:_canObjectMove(binding, direction)
  if binding.mapId ~= self.world.currentMapId then return false end
  local actor = binding.entity
  local vector = DIRECTIONS[direction]
  local x = actor.x + vector.x
  local y = actor.y + vector.y
  if x < 0 or y < 0
      or x >= self.world.grid.widthCells
      or y >= self.world.grid.heightCells then
    return false
  end
  if self.world.player.x == x and self.world.player.y == y then
    return false
  end
  if self.world:isObjectAt(x, y, actor) then return false end
  local collisionId = self.world.grid:collisionAt(x, y)
  return collisionId ~= nil
    and self.world.collision:allows(collisionId, direction)
end

function ActorSystem:_beginStep(id, direction)
  requireDirection(direction)
  local binding = self:binding(id)
  local actor = binding.entity
  actor.facing = direction
  if binding.player then
    return self.world:startMove(direction)
  end
  if actor.moving or not self:_canObjectMove(binding, direction) then
    return false
  end
  local vector = DIRECTIONS[direction]
  actor.moving = {
    direction = direction,
    elapsed = 0,
    fromX = actor.x,
    fromY = actor.y,
    targetX = actor.x + vector.x,
    targetY = actor.y + vector.y,
  }
  return true
end

function ActorSystem:startMovement(id, directions)
  self:binding(id)
  if self.motions[id] then fail("actor is already moving: " .. id, 2) end
  if type(directions) ~= "table" or #directions == 0 then
    fail("movement requires at least one direction", 2)
  end
  for _, direction in ipairs(directions) do requireDirection(direction) end
  self.motions[id] = {
    directions = copyArray(directions),
    index = 1,
    stepActive = false,
    succeeded = true,
  }
  self.motionResults[id] = nil
end

function ActorSystem:movementWait(id, directions)
  self:startMovement(id, directions)
  return ScriptRunner.wait(
    function()
      local motion = self.motions[id]
      if motion then return false end
      local result = self.motionResults[id]
      self.motionResults[id] = nil
      return true, result
    end,
    function()
      self.motions[id] = nil
      self.motionResults[id] = nil
      local actor = self:entity(id)
      actor.moving = nil
      actor.pixelX = actor.x * 16
      actor.pixelY = actor.y * 16
    end
  )
end

function ActorSystem:startFollowing(followerId, leaderId)
  if followerId == leaderId then fail("an actor cannot follow itself", 2) end
  self:binding(followerId)
  self:binding(leaderId)
  self.followers[followerId] = leaderId
end

function ActorSystem:stopFollowing(followerId)
  self.followers[followerId] = nil
end

function ActorSystem:showEmote(id, emoteId, duration)
  local actor = self:entity(id)
  if type(emoteId) ~= "string" or emoteId == "" then
    fail("emote id must be a non-empty string", 2)
  end
  if type(duration) ~= "number" or duration <= 0 then
    fail("emote duration must be positive", 2)
  end
  actor.emote = emoteId
  actor.emoteRemaining = duration
end

function ActorSystem:emoteWait(id, emoteId, duration)
  self:showEmote(id, emoteId, duration)
  return ScriptRunner.wait(function()
    return self:entity(id).emote == nil, true
  end)
end

function ActorSystem:_updateObject(actor, dt)
  local move = actor.moving
  if not move then return end
  move.elapsed = math.min(self.world.STEP_SECONDS, move.elapsed + dt)
  local alpha = move.elapsed / self.world.STEP_SECONDS
  actor.pixelX =
    (move.fromX + (move.targetX - move.fromX) * alpha) * 16
  actor.pixelY =
    (move.fromY + (move.targetY - move.fromY) * alpha) * 16
  if move.elapsed >= self.world.STEP_SECONDS then
    actor.x = move.targetX
    actor.y = move.targetY
    actor.pixelX = actor.x * 16
    actor.pixelY = actor.y * 16
    actor.moving = nil
  end
end

function ActorSystem:_queueFollower(leaderId, fromX, fromY)
  for _, followerId in ipairs(self.bindingOrder) do
    local targetId = self.followers[followerId]
    if targetId == leaderId and not self.motions[followerId] then
      local follower = self:entity(followerId)
      local dx = fromX - follower.x
      local dy = fromY - follower.y
      local direction = dx == 1 and dy == 0 and "right"
        or dx == -1 and dy == 0 and "left"
        or dy == 1 and dx == 0 and "down"
        or dy == -1 and dx == 0 and "up"
      if direction then
        self:startMovement(followerId, { direction })
      end
    end
  end
end

function ActorSystem:update(dt)
  for _, objects in pairs(self.world.objectStates) do
    for _, object in ipairs(objects) do
      self:_updateObject(object, dt)
    end
  end

  for _, id in ipairs(self.bindingOrder) do
    local binding = self.bindings[id]
    local actor = binding.entity
    if actor.emote then
      actor.emoteRemaining = actor.emoteRemaining - dt
      if actor.emoteRemaining <= 0 then
        actor.emote = nil
        actor.emoteRemaining = nil
      end
    end

    local motion = self.motions[id]
    if motion then
      if motion.stepActive and not actor.moving then
        self:_queueFollower(id, motion.fromX, motion.fromY)
        motion.index = motion.index + 1
        motion.stepActive = false
      end
      if not motion.stepActive then
        local direction = motion.directions[motion.index]
        if not direction then
          self.motionResults[id] = motion.succeeded
          self.motions[id] = nil
        else
          motion.fromX = actor.x
          motion.fromY = actor.y
          if self:_beginStep(id, direction) then
            motion.stepActive = true
          else
            motion.succeeded = false
            self.motionResults[id] = false
            self.motions[id] = nil
          end
        end
      end
    end
  end
end

return ActorSystem
