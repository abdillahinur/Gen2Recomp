return function(test, equal, truthy)
  local ActorCommandHandlers =
    require("src.script.ActorCommandHandlers")
  local Commands = require("src.script.Commands")
  local ScriptRunner = require("src.script.ScriptRunner")
  local World = require("src.world.World")

  local function fixture()
    local tileIds = {}
    for _ = 1, 16 do tileIds[#tileIds + 1] = 0 end
    local map = {
      id = "1:1",
      group = 1,
      tilesetId = 1,
      widthBlocks = 2,
      heightBlocks = 1,
      widthTiles = 8,
      heightTiles = 4,
      widthCells = 4,
      heightCells = 2,
      blocks = { 0, 0 },
      warps = {},
      connections = {},
      objects = {
        {
          id = 1,
          x = 0,
          y = 1,
          spriteId = 1,
          paletteId = 0,
        },
      },
    }
    return {
      initialMap = { mapId = "1:1", x = 1, y = 1 },
      groups = { { maps = { map } } },
      tilesets = {
        {
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
        },
      },
      collisionPermissions = {
        { id = 0, terrain = "land", directional = false },
      },
      sprites = {},
      roofs = {},
    }
  end

  local function setup()
    local world = World.new(fixture())
    world.actors:bind("crystal.actor.guide", "1:1", 1)
    local runner = ScriptRunner.new()
    ActorCommandHandlers.install(runner, { actors = world.actors })
    return world, runner
  end

  local noInput = { down = function() return false end }

  local function pump(world, runner, count)
    for _ = 1, count do
      world:update(World.STEP_SECONDS, noInput)
      runner:update(World.STEP_SECONDS)
    end
  end

  test("Actor commands face and move map objects", function()
    local world, runner = setup()
    local task = runner:start("guide-move", function()
      Commands.face("crystal.actor.guide", "up")
      return Commands.move(
        "crystal.actor.guide",
        { "up", "right" }
      )
    end)
    equal(task.state, "waiting")
    pump(world, runner, 3)
    equal(task.state, "completed")
    truthy(task.result)
    local guide = world.actors:entity("crystal.actor.guide")
    equal(guide.x, 1)
    equal(guide.y, 0)
    equal(guide.facing, "right")
  end)

  test("Following actors occupy the leader's previous tile", function()
    local world, runner = setup()
    local task = runner:start("follow", function()
      Commands.follow(
        "crystal.actor.guide",
        "common.actor.player"
      )
      return Commands.move("common.actor.player", { "right" })
    end)
    pump(world, runner, 4)
    equal(task.state, "completed")
    equal(world.player.x, 2)
    local guide = world.actors:entity("crystal.actor.guide")
    equal(guide.x, 1)
    equal(guide.y, 1)
  end)

  test("Emotes remain active for their requested duration", function()
    local world, runner = setup()
    local duration = World.STEP_SECONDS * 2.5
    local task = runner:start("emote", function()
      return Commands.emote(
        "crystal.actor.guide",
        "common.emote.notice",
        duration
      )
    end)
    pump(world, runner, 2)
    equal(task.state, "waiting")
    truthy(world.actors:entity("crystal.actor.guide").emote)
    pump(world, runner, 1)
    equal(task.state, "completed")
    equal(world.actors:entity("crystal.actor.guide").emote, nil)
  end)

  test("Blocked actor movement completes with false", function()
    local world, runner = setup()
    local task = runner:start("blocked", function()
      return Commands.move("crystal.actor.guide", { "left" })
    end)
    pump(world, runner, 1)
    equal(task.state, "completed")
    equal(task.result, false)
  end)
end
