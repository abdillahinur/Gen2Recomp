return function(test, equal, truthy)
  local AudioService = require("src.script.AudioService")
  local CoreCommandHandlers =
    require("src.script.CoreCommandHandlers")
  local DialogueService = require("src.script.DialogueService")
  local ScriptDefinition = require("src.script.ScriptDefinition")
  local ScriptRunner = require("src.script.ScriptRunner")
  local ScriptState = require("src.script.ScriptState")

  local introduction =
    require("data.scripts.crystal.flows.introduction")

  local function execute(genderChoice, name)
    local state = ScriptState.new()
    local dialogue = DialogueService.new()
    local audio = AudioService.new()
    local runner = ScriptRunner.new()
    local clockSetups = 0
    local requestedGender
    CoreCommandHandlers.install(runner, {
      state = state,
      dialogue = dialogue,
    })
    runner:register("system.clock.setup", function()
      clockSetups = clockSetups + 1
      return { hour = 10, minute = 0, weekday = "monday" }
    end)
    runner:register("ui.name.select", function(arguments)
      requestedGender = arguments.gender
      return name
    end)
    runner:register("audio.music.play", function(arguments)
      audio:playMusic(arguments.id, arguments.options)
    end)
    runner:register("audio.cry.play", function(arguments)
      audio:playCry(arguments.id, arguments.options)
    end)

    local task = runner:start(
      "crystal.introduction",
      introduction.behavior.run
    )
    equal(dialogue.active.kind, "choice")
    dialogue:choose(genderChoice)
    runner:update(0)

    while task.state == "waiting" do
      local active = dialogue.active
      if not active then break end
      equal(active.kind, "text")
      dialogue:advance()
      runner:update(0)
    end

    return {
      state = state,
      dialogue = dialogue,
      audio = audio,
      task = task,
      clockSetups = clockSetups,
      requestedGender = requestedGender,
    }
  end

  test("Crystal introduction definition is source-cited and valid", function()
    equal(ScriptDefinition.validate(introduction), introduction)
    equal(introduction.id, "crystal.flows.introduction")
    equal(#introduction.provenance, 4)
    equal(#introduction.coverage.scenes, 5)
  end)

  test("Crystal introduction runs female profile and naming order", function()
    local result = execute("crystal.profile.gender.girl", "PLAYER")
    equal(result.task.state, "completed")
    equal(result.task.result.gender, "female")
    equal(result.task.result.name, "PLAYER")
    equal(result.requestedGender, "female")
    equal(result.clockSetups, 1)
    equal(result.state:getVariable("player.gender"), "female")
    equal(result.state:getVariable("player.name"), "PLAYER")
    truthy(result.state:hasFlag(
      "crystal.story.introduction_complete"))
    equal(
      result.state:getScene("crystal.flow.introduction"),
      "crystal.scene.introduction.complete"
    )
  end)

  test("Crystal introduction presents professor beats without text", function()
    local result = execute("crystal.profile.gender.boy", "PLAYER")
    equal(result.task.state, "completed")
    equal(result.task.result.gender, "male")
    equal(#result.dialogue.transcript, 8)
    equal(
      result.dialogue.transcript[1].id,
      "crystal.choice.player_gender"
    )
    for index = 1, 7 do
      equal(
        result.dialogue.transcript[index + 1].id,
        "crystal.text.introduction.oak_" .. index
      )
    end
    equal(result.audio.events[1].kind, "music")
    equal(result.audio.events[2].kind, "cry")
  end)
end
