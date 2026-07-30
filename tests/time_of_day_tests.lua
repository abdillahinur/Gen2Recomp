return function(test, equal, raises)
  local TimeOfDay = require("src.world.TimeOfDay")

  test("TimeOfDay follows Crystal hour boundaries", function()
    local hour = 4
    local provider = TimeOfDay.new({
      clock = function() return { hour = hour } end,
    })
    equal(provider:period(), "morning")
    hour = 9
    equal(provider:period(), "morning")
    hour = 10
    equal(provider:period(), "day")
    hour = 17
    equal(provider:period(), "day")
    hour = 18
    equal(provider:period(), "night")
    hour = 3
    equal(provider:period(), "night")
  end)

  test("TimeOfDay supports forced map and injected periods", function()
    local provider = TimeOfDay.new({ fixedPeriod = "night" })
    equal(provider:forMap(0), "night")
    equal(provider:forMap(1), "day")
    equal(provider:forMap(2), "night")
    equal(provider:forMap(3), "morning")
    equal(provider:forMap(4), "dark")
    provider:setFixedPeriod("morning")
    equal(provider:period(), "morning")
    raises(function()
      provider:setFixedPeriod("sunset")
    end, "invalid")
  end)
end
