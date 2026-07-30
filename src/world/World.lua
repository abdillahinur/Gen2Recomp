local Camera = require("src.world.Camera")
local Collision = require("src.world.Collision")
local MapGrid = require("src.world.MapGrid")
local MapRepository = require("src.world.MapRepository")

local World = {}
World.__index = World

local STEP_SECONDS = 0.18
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
    },
    currentMapId = initial.mapId,
    currentMap = nil,
    grid = nil,
    warpCooldown = false,
    lastTransition = nil,
  }, World)
  self:loadMap(initial.mapId)
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
  self.grid = MapGrid.new(map, tileset)
end

function World:isObjectAt(x, y)
  for _, object in ipairs(self.currentMap.objects or {}) do
    if object.x == x and object.y == y then
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
  local grid = map.id == self.currentMapId
    and self.grid or MapGrid.new(map, tileset)
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
    fromMapId = self.currentMapId,
    fromX = self.player.x,
    fromY = self.player.y,
    targetMapId = map.id,
    targetX = x,
    targetY = y,
    visualTargetX = self.player.x + VECTORS[direction].x,
    visualTargetY = self.player.y + VECTORS[direction].y,
  }
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
  self:checkWarp()
end

function World:update(dt, input)
  local move = self.player.moving
  if move then
    move.elapsed = math.min(STEP_SECONDS, move.elapsed + dt)
    local alpha = move.elapsed / STEP_SECONDS
    self.player.pixelX =
      (move.fromX + (move.visualTargetX - move.fromX) * alpha) * 16
    self.player.pixelY =
      (move.fromY + (move.visualTargetY - move.fromY) * alpha) * 16
    if move.elapsed >= STEP_SECONDS then
      self:finishMove()
    end
  else
    for _, direction in ipairs({ "up", "down", "left", "right" }) do
      if input:down(direction) then
        self:startMove(direction)
        break
      end
    end
  end

  self.camera:follow(
    self.player.pixelX + 8,
    self.player.pixelY + 8,
    self.grid.widthTiles * 8,
    self.grid.heightTiles * 8
  )
end

World.STEP_SECONDS = STEP_SECONDS

return World
