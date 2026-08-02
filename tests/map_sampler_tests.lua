return function(test, equal)
  local World = require("src.world.World")
  local MapSampler = require("src.world.MapSampler")

  local function makeTiles(start)
    local tileIds = {}
    for id = start, start + 15 do
      tileIds[#tileIds + 1] = id
    end
    return tileIds
  end

  local function fixture()
    local tileset = {
      numericId = 1,
      metatiles = {
        records = {
          { id = 0, tileIds = makeTiles(0) },
          { id = 1, tileIds = makeTiles(16) },
          { id = 2, tileIds = makeTiles(32) },
        },
      },
      collision = {
        records = {
          {
            id = 0,
            topLeft = 0,
            topRight = 0,
            bottomLeft = 0,
            bottomRight = 0,
          },
          {
            id = 1,
            topLeft = 0,
            topRight = 0,
            bottomLeft = 0,
            bottomRight = 0,
          },
          {
            id = 2,
            topLeft = 0,
            topRight = 0,
            bottomLeft = 0,
            bottomRight = 0,
          },
        },
      },
    }
    local mapA = {
      id = "1:1",
      group = 1,
      tilesetId = 1,
      widthBlocks = 1,
      heightBlocks = 1,
      widthTiles = 4,
      heightTiles = 4,
      widthCells = 2,
      heightCells = 2,
      borderBlock = 2,
      blocks = { 0 },
      objects = {},
      warps = {},
      connections = {
        {
          direction = "east",
          targetMapId = "1:2",
          targetX = 0,
          targetY = 0,
        },
      },
    }
    local mapB = {
      id = "1:2",
      group = 1,
      tilesetId = 1,
      widthBlocks = 1,
      heightBlocks = 1,
      widthTiles = 4,
      heightTiles = 4,
      widthCells = 2,
      heightCells = 2,
      borderBlock = 2,
      blocks = { 1 },
      objects = {},
      warps = {},
      connections = {
        {
          direction = "west",
          targetMapId = "1:1",
          targetX = 1,
          targetY = 0,
        },
      },
    }
    return {
      initialMap = { mapId = "1:1", x = 1, y = 1 },
      groups = { { maps = { mapA, mapB } } },
      tilesets = { tileset },
      collisionPermissions = {
        { id = 0, terrain = "land", directional = false },
      },
      sprites = {},
      roofs = {},
    }
  end

  test("MapSampler returns in-map tiles unchanged", function()
    local world = World.new(fixture())
    local tileId = MapSampler.tileAt(world, 0, 0)
    equal(tileId, 0)
  end)

  test("MapSampler fills out-of-bounds with borderBlock metatile", function()
    local world = World.new(fixture())
    -- borderBlock 2 => tiles 32..47; tile (-1,-1) => local (3,3) => 47
    local tileId = MapSampler.tileAt(world, -1, -1)
    equal(tileId, 47)
  end)

  test("MapSampler reads connected map tiles past the east edge", function()
    local world = World.new(fixture())
    -- cell (2,0) is one cell past mapA's east edge -> mapB cell (0,0)
    -- tile (4,0) is the top-left tile of that cell on mapB block 1 => tile 16
    local tileId, tilesetId, map = MapSampler.tileAt(world, 4, 0)
    equal(map.id, "1:2")
    equal(tilesetId, 1)
    equal(tileId, 16)
  end)

  test("World camera stays centered at the map edge", function()
    local world = World.new(fixture())
    world.player.pixelX = 0
    world.player.pixelY = 0
    world:update(0, { down = function() return false end })
    equal(world.camera.x, 0 + 8 - 80)
    equal(world.camera.y, 0 + 8 - 72)
  end)
end
