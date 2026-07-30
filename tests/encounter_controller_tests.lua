return function(test, equal, truthy)
  local EncounterController = require("src.world.EncounterController")

  local function rng()
    return {
      nextByte = function() return 0 end,
    }
  end

  local function encounterData()
    local slots = {
      { level = 2, speciesNumber = 16, weight = 100 },
    }
    return {
      maps = {
        {
          mapId = "24:3",
          grass = {
            rates = { morning = 255, day = 255, night = 255 },
            periods = {
              morning = slots,
              day = slots,
              night = slots,
            },
          },
        },
      },
    }
  end

  local function world()
    return {
      stepCount = 0,
      currentMapId = "24:3",
      player = { x = 2, y = 3 },
      grid = {
        collisionAt = function() return 0x18 end,
      },
    }
  end

  test("encounter controller gates steps and dispatches battles", function()
    local started
    local resolve
    local bridge = {
      start = function(_, request, callback)
        started = request
        resolve = callback
      end,
    }
    local controller = EncounterController.new(
      encounterData(),
      bridge,
      { period = function() return "night" end },
      { rng = rng() }
    )
    local state = world()

    for step = 1, 5 do
      state.stepCount = step
      truthy(controller:afterStep(state, true) == nil)
    end
    equal(controller.cooldown, 0)
    state.stepCount = 6
    local request = controller:afterStep(state, true)
    equal(request, started)
    equal(request.options.speciesNumber, 16)
    equal(request.options.encounter.period, "night")
    truthy(controller.active)

    resolve({ outcome = "escaped" })
    truthy(not controller.active)
    equal(controller.cooldown,
      EncounterController.MAP_ENTRY_COOLDOWN)
    equal(controller.lastResult.outcome, "escaped")
  end)

  test("encounter controller respects map entry and script priority", function()
    local starts = 0
    local controller = EncounterController.new(
      encounterData(),
      {
        start = function() starts = starts + 1 end,
      },
      { period = function() return "day" end },
      { rng = rng(), canStart = function() return false end }
    )
    local state = world()
    state.stepCount = 1
    controller:afterStep(state, false)
    equal(controller.cooldown,
      EncounterController.MAP_ENTRY_COOLDOWN)

    state.currentMapId = "26:1"
    state.stepCount = 2
    controller:afterStep(state, true)
    equal(controller.cooldown,
      EncounterController.MAP_ENTRY_COOLDOWN)
    equal(starts, 0)
  end)
end
