return function(test, equal, truthy)
  local Collision = require("src.world.Collision")

  test("Collision applies terrain and directional permissions", function()
    local collision = Collision.new({
      { id = 0, terrain = "land", directional = false },
      { id = 1, terrain = "water", directional = false },
      { id = 2, terrain = "wall", directional = false },
      {
        id = 0xa0,
        terrain = "land",
        directional = true,
        directionKind = "ledge",
        directions = { "right" },
      },
      {
        id = 0xb0,
        terrain = "land",
        directional = true,
        directionKind = "wall",
        directions = { "right" },
      },
    })
    truthy(collision:allows(0, "up"))
    truthy(not collision:allows(1, "up"))
    truthy(not collision:allows(2, "up"))
    truthy(collision:allows(0xa0, "right"))
    truthy(not collision:allows(0xa0, "left"))
    truthy(not collision:allows(0xb0, "right"))
    truthy(collision:allows(0xb0, "left"))
    equal(collision:permission(99), nil)
  end)
end
