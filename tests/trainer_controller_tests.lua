return function(test, equal, truthy)
  local GameSession = require("src.game.GameSession")
  local TrainerController = require("src.world.TrainerController")

  local function fixture(blocked)
    local object = {
      id = 2,
      x = 0,
      y = 1,
      pixelX = 0,
      pixelY = 16,
      facing = "right",
      visible = true,
      sightRange = 4,
      trainer = {
        id = "crystal.trainer.22.001",
        classId = 22,
        partyId = 1,
        defeatFlagId = 1449,
      },
    }
    local actors = {
      object = object,
      motions = {},
      bind = function() return object end,
      showEmote = function(_, _, emote)
        object.emote = emote
      end,
      startMovement = function(self, id, directions)
        self.motions[id] = directions
      end,
      isControlled = function(self, id)
        return self.motions[id] ~= nil
      end,
      update = function(self)
        if object.emote then
          object.emote = nil
          return
        end
        for id, directions in pairs(self.motions) do
          for _, direction in ipairs(directions) do
            if direction == "right" then object.x = object.x + 1 end
          end
          object.pixelX = object.x * 16
          self.motions[id] = nil
        end
      end,
    }
    local world = {
      currentMapId = "26:1",
      stepCount = 1,
      player = { x = 3, y = 1, facing = "right" },
      actors = actors,
      currentObjects = function() return { object } end,
      isObjectAt = function(_, x, y)
        return blocked and x == 1 and y == 1
      end,
      grid = {
        collisionAt = function() return 0 end,
      },
      collision = {
        allows = function() return true end,
      },
    }
    return world, object
  end

  test("trainer sight approaches, battles, and persists defeat", function()
    local world, object = fixture(false)
    local session = GameSession.new("test_profile")
    local request
    local resolve
    local bridge = {
      start = function(_, value, callback)
        request = value
        resolve = callback
      end,
    }
    local controller = TrainerController.new(
      world,
      bridge,
      session,
      { rng = { nextByte = function() return 11 end } }
    )

    truthy(controller:afterStep(true))
    equal(object.emote, "shock")
    truthy(controller:isBusy())
    controller:update(TrainerController.EMOTE_SECONDS)
    controller:update(0.18)
    equal(object.x, 2)
    equal(request.opponentId, "crystal.trainer.22.001")
    equal(request.options.trainer.objectId, 2)
    equal(world.player.facing, "left")

    resolve({ outcome = "player_win", won = true })
    truthy(not controller:isBusy())
    truthy(session.state:hasFlag(
      TrainerController.defeatedFlag(object.trainer)))
    world.stepCount = 2
    truthy(not controller:afterStep(true))
  end)

  test("trainer sight is blocked by intervening objects", function()
    local world = fixture(true)
    local controller = TrainerController.new(
      world,
      { start = function() error("must not start") end },
      GameSession.new("test_profile")
    )
    truthy(not controller:afterStep(true))
  end)
end
