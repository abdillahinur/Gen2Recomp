local Camera = require("src.world.Camera")
local ActorSystem = require("src.world.ActorSystem")
local Collision = require("src.world.Collision")
local MapGrid = require("src.world.MapGrid")
local MapRepository = require("src.world.MapRepository")
local OverworldSpriteAnimator =
  require("src.render.OverworldSpriteAnimator")

local World = {}
World.__index = World

-- Integer frame step clock. Replaces the old 0.18s wall-clock duration.
local STEP_FRAMES = OverworldSpriteAnimator.STEP_FRAMES
local STEP_SECONDS = OverworldSpriteAnimator.STEP_SECONDS
local VECTORS = {
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
}
local CONNECTION_DIRECTIONS = {
  up = "north",
  down = "south",
  left = "west",
  right = "east",
}

local function findByPosition(values, x, y)
  for _, value in ipairs(values or {}) do
    if value.x == x and value.y == y then
      return value
    end
  end
end

local function findById(values, id)
  for _, value in ipairs(values or {}) do
    if value.id == id then
      return value
    end
  end
end

local function findConnection(map, direction)
  direction = CONNECTION_DIRECTIONS[direction] or direction
  for _, connection in ipairs(map.connections or {}) do
    if connection.direction == direction then
      return connection
    end
  end
end

local function runtimeObjects(repository)
  local byMap = {}
  for id, map in pairs(repository.maps) do
    local objects = {}
    for index, source in ipairs(map.objects or {}) do
      local object = {}
      for key, value in pairs(source) do object[key] = value end
      object.id = source.id or index
      object.pixelX = object.x * 16
      object.pixelY = object.y * 16
      object.facing = source.facing or "down"
      object.moving = nil
      object.visible = true
      objects[#objects + 1] = object
    end
    byMap[id] = objects
  end
  return byMap
end

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values or {}) do result[index] = value end
  return result
end

function World.new(worldData, options)
  options = options or {}
  local repository = options.repository or MapRepository.new(worldData)
  local initial = options.initialMap or worldData.initialMap
  local self = setmetatable({
    repository = repository,
    collision = Collision.new(worldData.collisionPermissions),
    camera = Camera.new(160, 144),
    player = {
      x = initial.x,
      y = initial.y,
      pixelX = initial.x * 16,
      pixelY = initial.y * 16,
      facing = "down",
      spriteId = options.playerSpriteId or 1,
      moving = nil,
      animPhase = 0,
    },
    currentMapId = initial.mapId,
    currentMap = nil,
    grid = nil,
    objectStates = runtimeObjects(repository),
    blockOverrides = {},
    warpCooldown = false,
    lastTransition = nil,
    stepCount = 0,
  }, World)
  self.STEP_FRAMES = STEP_FRAMES
  self.STEP_SECONDS = STEP_SECONDS
  self:loadMap(initial.mapId)
  self.actors = ActorSystem.new(self)
  self.warpCooldown = findByPosition(
    self.currentMap.warps,
    self.player.x,
    self.player.y
  ) ~= nil
  return self
end

function World:loadMap(id)
  local map = self.repository:getMap(id)
  if not map then
    error("world map is unavailable: " .. tostring(id), 2)
  end
  local tileset = self.repository:getTileset(map.tilesetId)
  if not tileset then
    error("world tileset is unavailable: " .. tostring(map.tilesetId), 2)
  end
  self.currentMapId = id
  self.currentMap = map
  local blocks = copyArray(map.blocks)
  for index, blockId in pairs(self.blockOverrides[id] or {}) do
    blocks[index] = blockId
  end
  local runtimeMap = {}
  for key, value in pairs(map) do runtimeMap[key] = value end
  runtimeMap.blocks = blocks
  self.grid = MapGrid.new(runtimeMap, tileset)
end

function World:relocate(mapId, x, y, facing, kind)
  local map = self.repository:getMap(mapId)
  if not map then error("world map is unavailable: " .. tostring(mapId), 2) end
  if type(x) ~= "number" or type(y) ~= "number"
      or x % 1 ~= 0 or y % 1 ~= 0
      or x < 0 or y < 0
      or x >= map.widthCells or y >= map.heightCells then
    error("world relocation is outside the target map", 2)
  end
  if facing ~= nil and not VECTORS[facing] then
    error("world relocation has an invalid facing direction", 2)
  end
  local sourceMapId = self.currentMapId
  self:loadMap(mapId)
  self.player.x = x
  self.player.y = y
  self.player.pixelX = x * 16
  self.player.pixelY = y * 16
  self.player.moving = nil
  if facing then self.player.facing = facing end
  self.warpCooldown =
    findByPosition(self.currentMap.warps, x, y) ~= nil
  self.lastTransition = {
    kind = kind or "relocate",
    sourceMapId = sourceMapId,
    targetMapId = mapId,
    resolved = true,
  }
end

function World:changeBlock(mapId, blockX, blockY, blockId)
  local map = self.repository:getMap(mapId)
  if not map then error("world map is unavailable: " .. tostring(mapId), 2) end
  if type(blockX) ~= "number" or type(blockY) ~= "number"
      or blockX % 1 ~= 0 or blockY % 1 ~= 0
      or blockX < 0 or blockY < 0
      or blockX >= map.widthBlocks or blockY >= map.heightBlocks then
    error("world block coordinates are outside the map", 2)
  end
  local tileset = self.repository:getTileset(map.tilesetId)
  if type(blockId) ~= "number" or blockId % 1 ~= 0
      or not tileset.metatiles.records[blockId + 1]
      or not tileset.collision.records[blockId + 1] then
    error("world block id is unavailable: " .. tostring(blockId), 2)
  end
  local index = blockY * map.widthBlocks + blockX + 1
  self.blockOverrides[mapId] = self.blockOverrides[mapId] or {}
  self.blockOverrides[mapId][index] = blockId
  if self.currentMapId == mapId then self:loadMap(mapId) end
end

function World:getObject(mapId, objectId)
  for _, object in ipairs(self.objectStates[mapId] or {}) do
    if object.id == objectId then return object end
  end
end

function World:currentObjects()
  return self.objectStates[self.currentMapId] or {}
end

function World:isObjectAt(x, y, ignored)
  for _, object in ipairs(self:currentObjects()) do
    if object ~= ignored and object.visible
        and object.x == x and object.y == y then
      return true
    end
  end
  return false
end

function World:connectionDestination(direction, x, y)
  local connection = findConnection(self.currentMap, direction)
  if not connection then
    return nil
  end
  local target = self.repository:getMap(connection.targetMapId)
  if not target then
    return nil
  end
  if direction == "left" or direction == "right" then
    return target, connection.targetX, y + connection.targetY
  end
  return target, x + connection.targetX, connection.targetY
end

function World:destination(direction)
  local vector = VECTORS[direction]
  local x = self.player.x + vector.x
  local y = self.player.y + vector.y
  if x >= 0 and y >= 0
      and x < self.grid.widthCells
      and y < self.grid.heightCells then
    return self.currentMap, x, y
  end
  return self:connectionDestination(direction, x, y)
end

function World:canMove(direction)
  local map, x, y = self:destination(direction)
  if not map then
    return false
  end
  if map.id == self.currentMapId and self:isObjectAt(x, y) then
    return false
  end
  local tileset = self.repository:getTileset(map.tilesetId)
  local grid
  if map.id == self.currentMapId then
    grid = self.grid
  else
    local blocks = copyArray(map.blocks)
    for index, blockId in pairs(self.blockOverrides[map.id] or {}) do
      blocks[index] = blockId
    end
    local runtimeMap = {}
    for key, value in pairs(map) do runtimeMap[key] = value end
    runtimeMap.blocks = blocks
    grid = MapGrid.new(runtimeMap, tileset)
  end
  local collisionId = grid:collisionAt(x, y)
  return collisionId ~= nil
    and self.collision:allows(collisionId, direction)
end

function World:startMove(direction)
  self.player.facing = direction
  if self.player.moving or not self:canMove(direction) then
    return false
  end
  local map, x, y = self:destination(direction)
  self.player.moving = {
    direction = direction,
    elapsed = 0,
    framesElapsed = 0,
    frameAccumulator = 0,
    animPhase = 0,
    fromMapId = self.currentMapId,
    fromX = self.player.x,
    fromY = self.player.y,
    targetMapId = map.id,
    targetX = x,
    targetY = y,
    visualTargetX = self.player.x + VECTORS[direction].x,
    visualTargetY = self.player.y + VECTORS[direction].y,
  }
  self.player.animPhase = 0
  return true
end

function World:checkWarp()
  local warp = findByPosition(
    self.currentMap.warps,
    self.player.x,
    self.player.y
  )
  if not warp then
    self.warpCooldown = false
    return
  end
  if self.warpCooldown then
    return
  end

  local targetMap = self.repository:getMap(warp.targetMapId)
  local targetWarp = targetMap
    and findById(targetMap.warps, warp.targetWarp)
  self.lastTransition = {
    kind = "warp",
    sourceMapId = self.currentMapId,
    sourceWarp = warp.id,
    targetMapId = warp.targetMapId,
    targetWarp = warp.targetWarp,
    resolved = targetMap ~= nil and targetWarp ~= nil,
  }
  if targetMap and targetWarp then
    self:loadMap(targetMap.id)
    self.player.x = targetWarp.x
    self.player.y = targetWarp.y
    self.player.pixelX = targetWarp.x * 16
    self.player.pixelY = targetWarp.y * 16
    self.warpCooldown = true
  end
end

function World:finishMove()
  local move = self.player.moving
  local changedMap = move.targetMapId ~= self.currentMapId
  if changedMap then
    self:loadMap(move.targetMapId)
    self.lastTransition = {
      kind = "connection",
      sourceMapId = move.fromMapId,
      targetMapId = move.targetMapId,
      direction = move.direction,
      resolved = true,
    }
  end
  self.player.x = move.targetX
  self.player.y = move.targetY
  self.player.pixelX = move.targetX * 16
  self.player.pixelY = move.targetY * 16
  self.player.moving = nil
  self.player.animPhase = 0
  self.stepCount = self.stepCount + 1
  self:checkWarp()
end

function World:update(dt, input)
  local move = self.player.moving
  if move then
    local alpha, done = OverworldSpriteAnimator.advanceMove(
      move,
      dt,
      STEP_FRAMES
    )
    move.elapsed = move.framesElapsed * OverworldSpriteAnimator.FRAME_SECONDS
    self.player.animPhase = move.animPhase
    self.player.pixelX =
      (move.fromX + (move.visualTargetX - move.fromX) * alpha) * 16
    self.player.pixelY =
      (move.fromY + (move.visualTargetY - move.fromY) * alpha) * 16
    if done then
      self:finishMove()
    end
  elseif not self.actors:isControlled("common.actor.player") then
    self.player.animPhase = 0
    for _, direction in ipairs({ "up", "down", "left", "right" }) do
      if input:down(direction) then
        self:startMove(direction)
        break
      end
    end
  end

  self.actors:update(dt)

  self.camera:follow(
    self.player.pixelX + 8,
    self.player.pixelY + 8,
    self.grid.widthTiles * 8,
    self.grid.heightTiles * 8
  )
end

World.STEP_FRAMES = STEP_FRAMES
World.STEP_SECONDS = STEP_SECONDS

return World
