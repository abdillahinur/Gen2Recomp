return function(test, equal, truthy)
  local AudioService = require("src.script.AudioService")
  local BattleService = require("src.script.BattleService")
  local Commands = require("src.script.Commands")
  local GameplayCommandHandlers =
    require("src.script.GameplayCommandHandlers")
  local ScriptRunner = require("src.script.ScriptRunner")
  local World = require("src.world.World")

  local function fixture()
    local tileZero, tileOne = {}, {}
    for _ = 1, 16 do
      tileZero[#tileZero + 1] = 0
      tileOne[#tileOne + 1] = 1
    end
    local function map(id, objects)
      return {
        id = id,
        group = 1,
        tilesetId = 1,
        widthBlocks = 1,
        heightBlocks = 1,
        widthTiles = 4,
        heightTiles = 4,
        widthCells = 2,
        heightCells = 2,
        blocks = { 0 },
        warps = {},
        connections = {},
        objects = objects or {},
      }
    end
    return {
      initialMap = { mapId = "1:1", x = 0, y = 0 },
      groups = {
        {
          maps = {
            map("1:1", {
              {
                id = 1,
                x = 1,
                y = 1,
                spriteId = 1,
                paletteId = 0,
              },
            }),
            map("1:2"),
          },
        },
      },
      tilesets = {
        {
          numericId = 1,
          metatiles = {
            records = {
              { id = 0, tileIds = tileZero },
              { id = 1, tileIds = tileOne },
            },
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
              {
                id = 1,
                topLeft = 1,
                topRight = 1,
                bottomLeft = 1,
                bottomRight = 1,
              },
            },
          },
        },
      },
      collisionPermissions = {
        { id = 0, terrain = "land", directional = false },
        { id = 1, terrain = "wall", directional = false },
      },
      sprites = {},
      roofs = {},
    }
  end

  local function setup()
    local world = World.new(fixture())
    world.actors:bind("crystal.actor.npc", "1:1", 1)
    local battles = BattleService.new()
    local audio = AudioService.new()
    local runner = ScriptRunner.new()
    GameplayCommandHandlers.install(runner, {
      world = world,
      actors = world.actors,
      battles = battles,
      audio = audio,
    })
    return runner, world, battles, audio
  end

  test("Gameplay commands mutate objects and map blocks", function()
    local runner, world = setup()
    local task = runner:start("map-mutations", function()
      Commands.hideObject("crystal.actor.npc")
      Commands.placeObject("crystal.actor.npc", 0, 1, "right")
      Commands.showObject("crystal.actor.npc")
      Commands.changeBlock("1:1", 0, 0, 1)
    end)
    equal(task.state, "completed")
    local object = world.actors:entity("crystal.actor.npc")
    truthy(object.visible)
    equal(object.x, 0)
    equal(object.y, 1)
    equal(object.facing, "right")
    equal(world.grid:tileAt(0, 0), 1)
    equal(world.grid:collisionAt(0, 0), 1)
  end)

  test("Warp and map-load commands relocate the player", function()
    local runner, world = setup()
    local task = runner:start("transitions", function()
      Commands.warp("1:2", 1, 0, "left")
      equal(world.lastTransition.kind, "script_warp")
      Commands.loadMap("1:1", 0, 1, "up")
      return world.currentMapId
    end)
    equal(task.state, "completed")
    equal(task.result, "1:1")
    equal(world.player.x, 0)
    equal(world.player.y, 1)
    equal(world.player.facing, "up")
    equal(world.lastTransition.kind, "map_change")
  end)

  test("Battle commands block until the battle adapter resolves", function()
    local runner, _, battles = setup()
    local task = runner:start("battle", function()
      return Commands.battle(
        "trainer",
        "crystal.trainer.rival.lab",
        { level = 5 }
      )
    end)
    equal(task.state, "waiting")
    equal(battles.active.opponentId, "crystal.trainer.rival.lab")
    truthy(battles:resolve({ outcome = "win" }))
    runner:update(0)
    equal(task.state, "completed")
    equal(task.result.outcome, "win")
  end)

  test("Audio commands route semantic events through the adapter", function()
    local runner, _, _, audio = setup()
    local task = runner:start("audio", function()
      Commands.playMusic("crystal.music.elms_lab")
      Commands.playSfx("crystal.sfx.item")
      Commands.playCry("crystal.species.cyndaquil")
      Commands.stopMusic({ fadeSeconds = 1 })
    end)
    equal(task.state, "completed")
    equal(#audio.events, 4)
    equal(audio.events[1].kind, "music")
    equal(audio.events[2].kind, "sfx")
    equal(audio.events[3].kind, "cry")
    equal(audio.events[4].kind, "music_stop")
    equal(audio.currentMusic, nil)
  end)
end
