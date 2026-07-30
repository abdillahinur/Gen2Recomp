return function(test, equal, truthy)
  local Commands = require("src.script.Commands")
  local GameSession = require("src.game.GameSession")
  local MapPresentationRuntime =
    require("src.script.MapPresentationRuntime")
  local World = require("src.world.World")

  local function input(action)
    return {
      down = function() return false end,
      wasPressed = function(_, candidate)
        return action == candidate
      end,
    }
  end

  local function world()
    local tileIds = {}
    for index = 1, 16 do tileIds[index] = 0 end
    return World.new({
      initialMap = { mapId = "1:1", x = 0, y = 0 },
      groups = {
        {
          maps = {
            {
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
              connections = {},
              warps = {},
              coordEvents = {},
              bgEvents = {},
              objects = { { id = 1, x = 0, y = 1 } },
            },
          },
        },
      },
      tilesets = {
        {
          numericId = 1,
          metatiles = { records = { { id = 0, tileIds = tileIds } } },
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
        },
      },
      collisionPermissions = {
        { id = 0, terrain = "land", directional = false },
      },
      sprites = {},
      roofs = {},
    })
  end

  test("map presentation runtime opens visible object dialogue", function()
    local definition = {
      kind = "map",
      maps = { "1:1" },
      actors = {},
      coverage = {
        callbacks = {},
        scenes = {},
        coordEvents = {},
        bgEvents = {},
        objects = { "test.map.object.greeter" },
      },
      behavior = {
        callbacks = {},
        scenes = {},
        coordEvents = {},
        bgEvents = {},
        objects = {
          ["test.map.object.greeter"] = function()
            Commands.text("test.text.greeting")
          end,
        },
      },
    }
    local catalog = {
      all = function() return { definition } end,
    }
    local gameSession = GameSession.new("test_profile")
    local value = MapPresentationRuntime.new(world(), {
      catalog = catalog,
      gameSession = gameSession,
    })
    equal(value.state, gameSession.state)
    equal(value.party, gameSession.party)
    truthy(value:updateIdle(input("confirm")))
    truthy(value:isBusy())
    equal(value.presentation:model().text, "TEXT · GREETING")
    value:updateActive(0, input("confirm"))
    value:updateActive(0, input())
    truthy(not value:isBusy())
    equal(#value.dialogue.transcript, 1)
  end)

  test("map presentation runtime dispatches coroutine battles", function()
    local definition = {
      kind = "map",
      maps = { "1:1" },
      actors = {},
      coverage = {
        callbacks = {},
        scenes = {},
        coordEvents = {},
        bgEvents = {},
        objects = { "test.map.object.battler" },
      },
      behavior = {
        callbacks = {},
        scenes = {},
        coordEvents = {},
        bgEvents = {},
        objects = {
          ["test.map.object.battler"] = function()
            local result = Commands.battle(
              "wild",
              "crystal.species.pidgey",
              { level = 2 }
            )
            Commands.setVariable(
              "test.battle.won",
              result.won
            )
          end,
        },
      },
    }
    local callback
    local request
    local bridge = {
      start = function(_, value, resolve)
        request = value
        callback = resolve
      end,
    }
    local value = MapPresentationRuntime.new(world(), {
      catalog = { all = function() return { definition } end },
      gameSession = GameSession.new("test_profile"),
      battleBridge = bridge,
    })
    truthy(value:updateIdle(input("confirm")))
    equal(request.kind, "wild")
    equal(request.opponentId, "crystal.species.pidgey")
    truthy(value:isBusy())
    callback({ outcome = "player_win", won = true })
    value:updateActive(0, input())
    truthy(not value:isBusy())
    truthy(value.state:getVariable("test.battle.won"))
  end)
end
