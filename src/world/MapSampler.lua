local MapGrid = require("src.world.MapGrid")

local MapSampler = {}

local function findConnection(map, direction)
  for _, connection in ipairs(map.connections or {}) do
    if connection.direction == direction then
      return connection
    end
  end
end

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values or {}) do
    result[index] = value
  end
  return result
end

local function mod(value, modulus)
  return ((value % modulus) + modulus) % modulus
end

local function gridFor(world, map)
  if map.id == world.currentMapId then
    return world.grid
  end
  world._samplerGrids = world._samplerGrids or {}
  local cached = world._samplerGrids[map.id]
  if cached then
    return cached
  end
  local tileset = world.repository:getTileset(map.tilesetId)
  local blocks = copyArray(map.blocks)
  for index, blockId in pairs(world.blockOverrides[map.id] or {}) do
    blocks[index] = blockId
  end
  local runtimeMap = {}
  for key, value in pairs(map) do
    runtimeMap[key] = value
  end
  runtimeMap.blocks = blocks
  local grid = MapGrid.new(runtimeMap, tileset)
  world._samplerGrids[map.id] = grid
  return grid
end

local function borderTileId(map, tileset, tileX, tileY)
  local blockId = map.borderBlock or 0
  local metatile = tileset.metatiles.records[blockId + 1]
  if not metatile then
    return 0
  end
  local localX = mod(tileX, 4)
  local localY = mod(tileY, 4)
  return metatile.tileIds[localY * 4 + localX + 1]
end

-- Resolve an off-map cell through a single-axis connection.
-- Corners (both axes out of range) fall through to border fill.
function MapSampler.resolveCell(world, cellX, cellY)
  local map = world.currentMap
  local width = map.widthCells
  local height = map.heightCells

  if cellX >= 0 and cellY >= 0 and cellX < width and cellY < height then
    return map, cellX, cellY
  end

  local connection
  local targetX
  local targetY

  if cellX < 0 and cellY >= 0 and cellY < height then
    connection = findConnection(map, "west")
    if connection then
      targetX = connection.targetX + cellX + 1
      targetY = cellY + connection.targetY
    end
  elseif cellX >= width and cellY >= 0 and cellY < height then
    connection = findConnection(map, "east")
    if connection then
      targetX = connection.targetX + (cellX - width)
      targetY = cellY + connection.targetY
    end
  elseif cellY < 0 and cellX >= 0 and cellX < width then
    connection = findConnection(map, "north")
    if connection then
      targetX = cellX + connection.targetX
      targetY = connection.targetY + cellY + 1
    end
  elseif cellY >= height and cellX >= 0 and cellX < width then
    connection = findConnection(map, "south")
    if connection then
      targetX = cellX + connection.targetX
      targetY = connection.targetY + (cellY - height)
    end
  end

  if not connection then
    return nil
  end
  local target = world.repository:getMap(connection.targetMapId)
  if not target then
    return nil
  end
  if targetX < 0 or targetY < 0
      or targetX >= target.widthCells
      or targetY >= target.heightCells then
    return nil
  end
  return target, targetX, targetY
end

function MapSampler.tileAt(world, tileX, tileY)
  local map = world.currentMap
  local tileset = world.repository:getTileset(map.tilesetId)

  if tileX >= 0 and tileY >= 0
      and tileX < map.widthTiles and tileY < map.heightTiles then
    return world.grid:tileAt(tileX, tileY), map.tilesetId, map
  end

  local cellX = math.floor(tileX / 2)
  local cellY = math.floor(tileY / 2)
  local target, targetCellX, targetCellY =
    MapSampler.resolveCell(world, cellX, cellY)
  if target then
    local subX = tileX - cellX * 2
    local subY = tileY - cellY * 2
    local localTileX = targetCellX * 2 + subX
    local localTileY = targetCellY * 2 + subY
    local grid = gridFor(world, target)
    local tileId = grid:tileAt(localTileX, localTileY)
    if tileId ~= nil then
      return tileId, target.tilesetId, target
    end
  end

  return borderTileId(map, tileset, tileX, tileY), map.tilesetId, map
end

function MapSampler.clearCache(world)
  world._samplerGrids = nil
end

return MapSampler
