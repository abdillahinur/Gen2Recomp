return function(test, equal, truthy)
  local CoreCommandHandlers =
    require("src.script.CoreCommandHandlers")
  local DialogueService = require("src.script.DialogueService")
  local ScriptCatalog = require("src.script.ScriptCatalog")
  local ScriptDefinition = require("src.script.ScriptDefinition")
  local ScriptRunner = require("src.script.ScriptRunner")
  local ScriptState = require("src.script.ScriptState")

  local cherrygrove =
    require("data.scripts.crystal.maps.cherrygrove_city")
  local mrPokemon =
    require("data.scripts.crystal.maps.mr_pokemons_house")
  local route32 =
    require("data.scripts.crystal.maps.route_32")

  local immediateCommands = {
    "actor.emote",
    "actor.face",
    "actor.move",
    "audio.music.play",
    "audio.sfx.play",
    "inventory.item.give",
    "world.object.hide",
    "world.object.show",
  }

  local function setup()
    local state = ScriptState.new()
    local dialogue = DialogueService.new()
    local runner = ScriptRunner.new()
    local commands = {}
    CoreCommandHandlers.install(runner, {
      state = state,
      dialogue = dialogue,
    })
    for _, name in ipairs(immediateCommands) do
      local commandName = name
      runner:register(commandName, function(arguments)
        commands[#commands + 1] = {
          name = commandName,
          arguments = arguments,
        }
        return true
      end)
    end
    runner:register("gameplay.battle", function(arguments)
      commands[#commands + 1] = {
        name = "gameplay.battle",
        arguments = arguments,
      }
      return { outcome = "player_win", won = true }
    end)
    return runner, state, dialogue, commands
  end

  local function drive(runner, dialogue, task, choose)
    local attempts = 0
    while task.state ~= "completed" and task.state ~= "failed" do
      attempts = attempts + 1
      if attempts > 200 then error("route script did not finish") end
      local active = dialogue.active
      if active and active.kind == "text" then
        dialogue:advance()
      elseif active and active.kind == "choice" then
        dialogue:choose(choose and choose(active)
          or "common.choice.yes")
      end
      runner:update(1)
    end
  end

  test("Violet-route definitions validate and cover core maps", function()
    equal(ScriptDefinition.validate(cherrygrove), cherrygrove)
    equal(ScriptDefinition.validate(mrPokemon), mrPokemon)
    equal(ScriptDefinition.validate(route32), route32)
    local catalog = ScriptCatalog.load()
    equal(catalog:forMap("24:3").id, "crystal.maps.route_29")
    equal(catalog:forMap("26:1").id, "crystal.maps.route_30")
    equal(catalog:forMap("26:10").id,
      "crystal.maps.mr_pokemons_house")
    equal(catalog:forMap("10:5").id, "crystal.maps.violet_city")
  end)

  test("Mr Pokemon meeting grants Egg and Pokedex story state", function()
    local runner, state, dialogue, commands = setup()
    local task = runner:start(
      "mr-pokemon-meeting",
      mrPokemon.behavior.scenes[
        "crystal.mr_pokemon.scene.meeting"
      ]
    )
    drive(runner, dialogue, task)
    equal(task.state, "completed")
    truthy(state:hasFlag("crystal.story.got_mystery_egg"))
    truthy(state:hasFlag("crystal.story.got_pokedex"))
    truthy(state:hasFlag("crystal.feature.pokedex"))
    truthy(state:hasFlag("crystal.story.elms_lab_robbed"))
    equal(
      state:getScene("crystal.map.mr_pokemons_house"),
      "crystal.scene.mr_pokemons_house.complete"
    )
    local egg
    for _, command in ipairs(commands) do
      if command.name == "inventory.item.give"
          and command.arguments.itemId == "crystal.item.mystery_egg" then
        egg = command
      end
    end
    truthy(egg)
  end)

  test("Cherrygrove rival gate dispatches and persists battle", function()
    local runner, state, dialogue, commands = setup()
    state:setFlag("crystal.story.got_pokedex")
    local task = runner:start(
      "cherrygrove-rival",
      cherrygrove.behavior.coordEvents[
        "crystal.cherrygrove.coord.rival_north"
      ]
    )
    drive(runner, dialogue, task)
    equal(task.state, "completed")
    truthy(state:hasFlag(
      "crystal.story.beat_cherrygrove_rival"))
    local battle
    for _, command in ipairs(commands) do
      if command.name == "gameplay.battle" then battle = command end
    end
    equal(battle.arguments.kind, "trainer")
    equal(
      battle.arguments.opponentId,
      "crystal.trainer.rival.lab"
    )
  end)

  test("Route 32 guard returns pre-badge players to Violet", function()
    local runner, state, dialogue, commands = setup()
    local task = runner:start(
      "route-32-guard",
      route32.behavior.coordEvents[
        "crystal.route_32.coord.badge_guard"
      ]
    )
    drive(runner, dialogue, task)
    equal(task.state, "completed")
    local movement
    for _, command in ipairs(commands) do
      if command.name == "actor.move" then movement = command end
    end
    equal(movement.arguments.id, "common.actor.player")
    equal(#movement.arguments.directions, 2)
    truthy(not state:hasFlag("crystal.badge.zephyr"))
  end)
end
