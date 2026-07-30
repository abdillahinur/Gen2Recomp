return function(test, equal)
  local AudioRuntime = require("src.audio.AudioRuntime")
  local AudioService = require("src.script.AudioService")

  test("audio runtime dispatches music SFX and cries once", function()
    local calls = {}
    local sink = {}
    for _, method in ipairs({
      "playMusic", "stopMusic", "playSfx", "playCry",
    }) do
      sink[method] = function(_, id)
        calls[#calls + 1] = { method = method, id = id }
      end
    end
    local service = AudioService.new()
    local runtime = AudioRuntime.new(service, sink)
    service:playMusic("crystal.music.route_29")
    service:playSfx("crystal.sfx.menu_open")
    service:playCry("crystal.species.cyndaquil")
    service:stopMusic()
    runtime:update()
    equal(#calls, 4)
    equal(calls[1].method, "playMusic")
    equal(calls[2].method, "playSfx")
    equal(calls[3].method, "playCry")
    equal(calls[4].method, "stopMusic")
    runtime:update()
    equal(#calls, 4)
  end)
end
