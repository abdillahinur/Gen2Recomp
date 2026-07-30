local MapGrid = {}
MapGrid.__index = MapGrid

local function at(records, id, kind)
  local value = records[id + 1]
  if not value then
    error(("%s id %d is unavailable"):format(kind, id), 3)
  end
  return value
end

function MapGrid.new(map, tileset)
  local self = setmetatable({
    map = map,
    tileset = tileset,
    widthTiles = map.widthTiles,
    heightTiles = map.heightTiles,
    widthCells = map.widthCells,
    heightCells = map.heightCells,
    tileIds = {},
    collisionIds = {},
  }, MapGrid)

  for blockY = 0, map.heightBlocks - 1 do
    for blockX = 0, map.widthBlocks - 1 do
      local blockIndex = blockY * map.widthBlocks + blockX + 1
      local blockId = map.blocks[blockIndex]
      local metatile = at(
        tileset.metatiles.records,
        blockId,
        "metatile"
      )
      local collision = at(
        tileset.collision.records,
        blockId,
        "collision"
      )

      for localY = 0, 3 do
        for localX = 0, 3 do
          local tileX = blockX * 4 + localX
          local tileY = blockY * 4 + localY
          local destination = tileY * self.widthTiles + tileX + 1
          local source = localY * 4 + localX + 1
          self.tileIds[destination] = metatile.tileIds[source]
        end
      end

      local collisions = {
        collision.topLeft,
        collision.topRight,
        collision.bottomLeft,
        collision.bottomRight,
      }
      for localY = 0, 1 do
        for localX = 0, 1 do
          local cellX = blockX * 2 + localX
          local cellY = blockY * 2 + localY
          local destination = cellY * self.widthCells + cellX + 1
          self.collisionIds[destination] =
            collisions[localY * 2 + localX + 1]
        end
      end
    end
  end
  return self
end

function MapGrid:tileAt(x, y)
  if x < 0 or y < 0 or x >= self.widthTiles or y >= self.heightTiles then
    return nil
  end
  return self.tileIds[y * self.widthTiles + x + 1]
end

function MapGrid:collisionAt(x, y)
  if x < 0 or y < 0 or x >= self.widthCells or y >= self.heightCells then
    return nil
  end
  return self.collisionIds[y * self.widthCells + x + 1]
end

return MapGrid
