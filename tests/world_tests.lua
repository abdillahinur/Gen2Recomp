return function(test, equal, truthy)
  local World = require("src.world.World")

  local function fixture(options)
    options = options or {}
    local tileIds = {}
    for _ = 1, 16 do tileIds[#tileIds + 1] = 0 end
    local tileset = {
      numericId = 1,
      metatiles = {
        records = { { id = 0, tileIds = tileIds } },
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
      blocks = { 0 },
      objects = options.objects or {},
      warps = {
        {
          id = 1,
          x = 0,
          y = 0,
          targetMapId = "1:2",
          targetWarp = 1,
        },
      },
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
      blocks = { 0 },
      objects = {},
      warps = {
        {
          id = 1,
          x = 1,
          y = 1,
          targetMapId = "1:1",
          targetWarp = 1,
        },
      },
      connections = {},
    }
    return {
      initialMap = {
        mapId = "1:1",
        x = options.x or 0,
        y = options.y or 1,
      },
      groups = { { maps = { mapA, mapB } } },
      tilesets = { tileset },
      collisionPermissions = {
        { id = 0, terrain = "land", directional = false },
      },
      sprites = {},
      roofs = {},
    }
  end

  local function finish(world)
    world:update(World.STEP_SECONDS, {
      down = function() return false end,
    })
  end

  test("World moves on the grid and updates facing", function()
    local world = World.new(fixture())
    truthy(world:startMove("right"))
    finish(world)
    equal(world.player.x, 1)
    equal(world.player.y, 1)
    equal(world.player.facing, "right")
    equal(world.player.pixelX, 16)
    equal(world.stepCount, 1)
  end)

  test("World blocks occupied cells while preserving facing", function()
    local world = World.new(fixture({
      objects = { { x = 1, y = 1 } },
    }))
    truthy(not world:startMove("right"))
    equal(world.player.x, 0)
    equal(world.player.facing, "right")
  end)

  test("World resolves warps by target map and warp id", function()
    local world = World.new(fixture())
    truthy(world:startMove("up"))
    finish(world)
    equal(world.currentMapId, "1:2")
    equal(world.player.x, 1)
    equal(world.player.y, 1)
    equal(world.lastTransition.kind, "warp")
    truthy(world.lastTransition.resolved)
  end)

  test("World crosses map connections without long tweening", function()
    local world = World.new(fixture({ x = 1, y = 1 }))
    truthy(world:startMove("right"))
    world:update(World.STEP_SECONDS / 2, {
      down = function() return false end,
    })
    truthy(world.player.pixelX < 32)
    finish(world)
    equal(world.currentMapId, "1:2")
    equal(world.player.x, 0)
    equal(world.player.y, 1)
    equal(world.lastTransition.kind, "connection")
  end)
end
