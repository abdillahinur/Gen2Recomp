return function(test, equal)
  local Camera = require("src.world.Camera")

  test("Camera centers the follow point without clamping to map bounds", function()
    local camera = Camera.new(160, 144)
    camera:follow(8, 8)
    equal(camera.x, 8 - 80)
    equal(camera.y, 8 - 72)

    camera:follow(0, 0)
    equal(camera.x, -80)
    equal(camera.y, -72)

    camera:follow(400, 300)
    equal(camera.x, 400 - 80)
    equal(camera.y, 300 - 72)
  end)
end
