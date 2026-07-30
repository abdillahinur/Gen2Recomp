return function(test, equal)
  local LogicalCanvas = require("src.render.LogicalCanvas")

  test("LogicalCanvas preserves 160 by 144 integer scaling", function()
    local layout = LogicalCanvas.layout(800, 720)
    equal(LogicalCanvas.WIDTH, 160)
    equal(LogicalCanvas.HEIGHT, 144)
    equal(layout.scale, 5)
    equal(layout.width, 800)
    equal(layout.height, 720)
    equal(layout.x, 0)
    equal(layout.y, 0)

    layout = LogicalCanvas.layout(1000, 800)
    equal(layout.scale, 5)
    equal(layout.x, 100)
    equal(layout.y, 40)
  end)
end
