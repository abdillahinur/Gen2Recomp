local BattleRng = require("src.battle.BattleRng")

local TrainerController = {}
TrainerController.__index = TrainerController

local VECTORS = {
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
}
local OPPOSITE = {
  up = "down",
  down = "up",
  left = "right",
  right = "left",
}
local EMOTE_SECONDS = 0.5

local function defeatedFlag(trainer)
  return "crystal.trainer.defeated.f" .. trainer.defeatFlagId
end

local function distanceInFront(object, player)
  local vector = VECTORS[object.facing]
  if not vector then return nil end
  local dx = player.x - object.x
  local dy = player.y - object.y
  if vector.x ~= 0 and dy == 0 and dx * vector.x > 0 then
    return math.abs(dx), vector
  elseif vector.y ~= 0 and dx == 0 and dy * vector.y > 0 then
    return math.abs(dy), vector
  end
end

local function clearSightLine(world, object, distance, vector)
  for step = 1, distance do
    local x = object.x + vector.x * step
    local y = object.y + vector.y * step
    local collision = world.grid:collisionAt(x, y)
    if collision == nil
        or not world.collision:allows(collision, object.facing) then
      return false
    end
    if step < distance and world:isObjectAt(x, y, object) then
      return false
    end
  end
  return true
end

function TrainerController.new(world, battleBridge, gameSession, options)
  if type(world) ~= "table" or type(world.currentObjects) ~= "function" then
    error("trainer controller requires a world", 2)
  end
  if type(battleBridge) ~= "table"
      or type(battleBridge.start) ~= "function" then
    error("trainer controller requires a battle bridge", 2)
  end
  if type(gameSession) ~= "table"
      or type(gameSession.state) ~= "table" then
    error("trainer controller requires a game session", 2)
  end
  options = options or {}
  return setmetatable({
    world = world,
    bridge = battleBridge,
    gameSession = gameSession,
    rng = options.rng or BattleRng.new(options.seed or 7),
    lastStep = 0,
    bindings = {},
    active = nil,
    lastResult = nil,
  }, TrainerController)
end

function TrainerController:isBusy()
  return self.active ~= nil
end

function TrainerController:_bind(object)
  local key = self.world.currentMapId .. ":" .. object.id
  local id = self.bindings[key]
  if not id then
    id = "crystal.actor.trainer." .. key
    self.world.actors:bind(id, self.world.currentMapId, object.id)
    self.bindings[key] = id
  end
  return id
end

function TrainerController:_find()
  for _, object in ipairs(self.world:currentObjects()) do
    local trainer = object.trainer
    if trainer and object.visible and object.sightRange > 0
        and not self.gameSession.state:hasFlag(
          defeatedFlag(trainer)) then
      local distance, vector =
        distanceInFront(object, self.world.player)
      if distance and distance <= object.sightRange
          and clearSightLine(self.world, object, distance, vector) then
        return object, trainer, distance
      end
    end
  end
end

function TrainerController:afterStep(enabled)
  local step = self.world.stepCount or 0
  if step <= self.lastStep then return false end
  self.lastStep = step
  if not enabled or self.active then return false end

  local object, trainer, distance = self:_find()
  if not object then return false end
  local actorId = self:_bind(object)
  self.world.actors:showEmote(actorId, "shock", EMOTE_SECONDS)
  local directions = {}
  for _ = 1, distance - 1 do directions[#directions + 1] = object.facing end
  self.active = {
    phase = "emote",
    object = object,
    trainer = trainer,
    actorId = actorId,
    directions = directions,
  }
  return true
end

function TrainerController:_startBattle()
  local active = self.active
  self.world.player.facing = OPPOSITE[active.object.facing]
  active.phase = "battle"
  local controller = self
  self.bridge:start({
    kind = "trainer",
    opponentId = active.trainer.id,
    options = {
      seed = self.rng:nextByte(),
      trainer = {
        mapId = self.world.currentMapId,
        objectId = active.object.id,
        defeatFlagId = active.trainer.defeatFlagId,
      },
    },
  }, function(result)
    if result.won then
      controller.gameSession.state:setFlag(
        defeatedFlag(active.trainer)
      )
    end
    controller.lastResult = result
    controller.active = nil
  end)
end

function TrainerController:update(dt)
  local active = self.active
  if not active or active.phase == "battle" then return end
  self.world.actors:update(dt)
  if active.phase == "emote" and active.object.emote == nil then
    if #active.directions > 0 then
      self.world.actors:startMovement(
        active.actorId,
        active.directions
      )
      active.phase = "approach"
    else
      self:_startBattle()
    end
  elseif active.phase == "approach"
      and not self.world.actors:isControlled(active.actorId) then
    self:_startBattle()
  end
end

TrainerController.EMOTE_SECONDS = EMOTE_SECONDS
TrainerController.defeatedFlag = defeatedFlag

return TrainerController
