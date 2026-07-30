return function(test, equal)
  local MapGrid = require("src.world.MapGrid")

  test("MapGrid expands blocks into tiles and movement cells", function()
    local tileIds = {}
    for id = 0, 15 do
      tileIds[#tileIds + 1] = id
    end
    local map = {
      widthBlocks = 1,
      heightBlocks = 1,
      widthTiles = 4,
      heightTiles = 4,
      widthCells = 2,
      heightCells = 2,
      blocks = { 0 },
    }
    local tileset = {
      metatiles = {
        records = { { id = 0, tileIds = tileIds } },
      },
      collision = {
        records = {
          {
            id = 0,
            topLeft = 1,
            topRight = 2,
            bottomLeft = 3,
            bottomRight = 4,
          },
        },
      },
    }
    local grid = MapGrid.new(map, tileset)
    equal(grid:tileAt(0, 0), 0)
    equal(grid:tileAt(3, 3), 15)
    equal(grid:collisionAt(0, 0), 1)
    equal(grid:collisionAt(1, 1), 4)
    equal(grid:tileAt(4, 0), nil)
  end)
end
