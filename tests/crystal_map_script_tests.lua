return function(test, equal, truthy)
  local CoreCommandHandlers =
    require("src.script.CoreCommandHandlers")
  local DialogueService = require("src.script.DialogueService")
  local ScriptDefinition = require("src.script.ScriptDefinition")
  local ScriptRunner = require("src.script.ScriptRunner")
  local ScriptState = require("src.script.ScriptState")

  local newBark =
    require("data.scripts.crystal.maps.new_bark_town")
  local elmsLab =
    require("data.scripts.crystal.maps.elms_lab")

  local immediateCommands = {
    "actor.emote",
    "actor.face",
    "actor.follow.start",
    "actor.follow.stop",
    "actor.move",
    "audio.cry.play",
    "audio.music.play",
    "audio.sfx.play",
    "inventory.item.give",
    "party.pokemon.give",
    "phone.contact.register",
    "world.object.hide",
    "world.object.place",
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
    runner:register("actor.state.get", function(arguments)
      commands[#commands + 1] = {
        name = "actor.state.get",
        arguments = arguments,
      }
      return { x = 6, y = 4, facing = "up", visible = true }
    end)
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
    return runner, state, dialogue, commands
  end

  local function drive(runner, dialogue, task, choose)
    local attempts = 0
    while task.state ~= "completed" and task.state ~= "failed" do
      attempts = attempts + 1
      if attempts > 100 then error("map script did not finish") end
      local active = dialogue.active
      if active and active.kind == "text" then
        dialogue:advance()
      elseif active and active.kind == "choice" then
        dialogue:choose(choose(active))
      end
      runner:update(1)
    end
  end

  test("New Bark and Elm Lab definitions validate provenance", function()
    equal(ScriptDefinition.validate(newBark), newBark)
    equal(ScriptDefinition.validate(elmsLab), elmsLab)
    equal(#newBark.actors, 3)
    equal(#elmsLab.actors, 6)
    equal(#newBark.coverage.bgEvents, 4)
    equal(#elmsLab.coverage.bgEvents, 16)
    equal(#elmsLab.coverage.objects, 6)
  end)

  test("New Bark callback and teacher branches update native state", function()
    local runner, state, dialogue =
      setup()
    state:setFlag("crystal.story.first_time_banking_with_mom")
    local callback = runner:start(
      "new-bark-callback",
      newBark.behavior.callbacks[
        "crystal.new_bark.callback.new_map"
      ]
    )
    equal(callback.state, "completed")
    truthy(state:hasFlag("crystal.world.flypoint.new_bark"))
    truthy(not state:hasFlag(
      "crystal.story.first_time_banking_with_mom"))

    state:setFlag("crystal.story.got_starter")
    local interaction = runner:start(
      "new-bark-teacher",
      newBark.behavior.objects[
        "crystal.new_bark.object.teacher"
      ]
    )
    equal(
      dialogue.active.id,
      "crystal.text.new_bark.pokemon_is_adorable"
    )
    drive(runner, dialogue, interaction, function()
      return "common.choice.yes"
    end)
    equal(interaction.state, "completed")
  end)

  test("Elm meeting repeats refusal then opens starter selection", function()
    local runner, state, dialogue = setup()
    state:setScene(
      "crystal.map.elms_lab",
      "crystal.scene.elms_lab.meet_elm"
    )
    local refusals = 0
    local task = runner:start(
      "meet-elm",
      elmsLab.behavior.scenes[
        "crystal.elms_lab.scene.meet_elm"
      ]
    )
    drive(runner, dialogue, task, function(active)
      equal(active.id, "crystal.choice.elms_lab.help_elm")
      refusals = refusals + 1
      if refusals == 1 then return "common.choice.no" end
      return "common.choice.yes"
    end)
    equal(task.state, "completed")
    equal(refusals, 2)
    equal(
      state:getScene("crystal.map.elms_lab"),
      "crystal.scene.elms_lab.cant_leave"
    )
    local sawRefusal = false
    for _, event in ipairs(dialogue.transcript) do
      if event.id == "crystal.text.elms_lab.elm_refused" then
        sawRefusal = true
      end
    end
    truthy(sawRefusal)
  end)

  test("all Elm starters grant the selected level-five Pokemon", function()
    for _, species in ipairs({
      "cyndaquil",
      "totodile",
      "chikorita",
    }) do
      local runner, state, dialogue, commands = setup()
      local task = runner:start(
        "inspect-" .. species,
        elmsLab.behavior.objects[
          "crystal.elms_lab.object." .. species .. "_ball"
        ]
      )
      drive(runner, dialogue, task, function(active)
        equal(
          active.id,
          "crystal.choice.elms_lab.take_" .. species
        )
        return "common.choice.yes"
      end)
      equal(task.state, "completed")
      equal(task.result, species)
      truthy(state:hasFlag("crystal.story.got_starter"))
      truthy(state:hasFlag(
        "crystal.story.got_" .. species .. "_from_elm"
      ))

      local granted
      for _, command in ipairs(commands) do
        if command.name == "party.pokemon.give" then
          granted = command.arguments
        end
      end
      equal(granted.speciesId, "crystal.species." .. species)
      equal(granted.level, 5)
      equal(granted.heldItemId, "crystal.item.berry")
    end
  end)

  test("Elm Lab officer dispatches investigation and exits", function()
    local runner, state, dialogue, commands = setup()
    state:setScene(
      "crystal.map.elms_lab",
      "crystal.scene.elms_lab.meet_officer"
    )
    local task = runner:start(
      "elm-lab-officer",
      elmsLab.behavior.objects[
        "crystal.elms_lab.object.officer"
      ]
    )
    drive(runner, dialogue, task, function()
      return "common.choice.yes"
    end)
    equal(task.state, "completed")
    equal(
      state:getScene("crystal.map.elms_lab"),
      "crystal.scene.elms_lab.noop"
    )
    equal(
      dialogue.transcript[1].id,
      "crystal.text.elms_lab.officer_intro"
    )
    equal(
      dialogue.transcript[2].id,
      "crystal.text.elms_lab.officer_named_rival"
    )
    local hidOfficer = false
    for _, command in ipairs(commands) do
      if command.name == "world.object.hide"
          and command.arguments.id
            == "crystal.elms_lab.actor.officer" then
        hidOfficer = true
      end
    end
    truthy(hidOfficer)
  end)
end
