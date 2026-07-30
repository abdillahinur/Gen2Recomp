return function(test, equal, truthy, raises)
  local Commands = require("src.script.Commands")
  local CoreCommandHandlers =
    require("src.script.CoreCommandHandlers")
  local DialogueService = require("src.script.DialogueService")
  local ScriptRunner = require("src.script.ScriptRunner")
  local ScriptState = require("src.script.ScriptState")

  local function services()
    local state = ScriptState.new()
    local dialogue = DialogueService.new()
    local runner = ScriptRunner.new()
    CoreCommandHandlers.install(runner, {
      state = state,
      dialogue = dialogue,
    })
    return runner, state, dialogue
  end

  test("State commands mutate flags scenes and scalar variables", function()
    local runner, state = services()
    local task = runner:start("state", function()
      truthy(not Commands.hasFlag("crystal.story.met_elm"))
      Commands.setFlag("crystal.story.met_elm")
      Commands.setScene(
        "crystal.map.elms_lab",
        "crystal.scene.choose_starter"
      )
      Commands.setVariable("player.name", "KRIS")
      return {
        flag = Commands.hasFlag("crystal.story.met_elm"),
        scene = Commands.getScene("crystal.map.elms_lab"),
        name = Commands.getVariable("player.name", "PLAYER"),
      }
    end)
    equal(task.state, "completed")
    truthy(task.result.flag)
    equal(task.result.scene, "crystal.scene.choose_starter")
    equal(task.result.name, "KRIS")
    truthy(state:hasFlag("crystal.story.met_elm"))
  end)

  test("Text and choices block until presentation resolves", function()
    local runner, _, dialogue = services()
    local task = runner:start("dialogue", function()
      Commands.text("crystal.text.elm.greeting", { player = "KRIS" })
      return Commands.choice("crystal.choice.confirm_name", {
        {
          id = "common.choice.yes",
          textId = "common.text.yes",
        },
        {
          id = "common.choice.no",
          textId = "common.text.no",
        },
      })
    end)
    equal(task.state, "waiting")
    equal(dialogue.active.kind, "text")
    truthy(dialogue:advance())
    runner:update(0)
    equal(task.state, "waiting")
    equal(dialogue.active.kind, "choice")
    truthy(dialogue:choose("common.choice.yes"))
    runner:update(0)
    equal(task.state, "completed")
    equal(task.result, "common.choice.yes")
    equal(#dialogue.transcript, 2)
  end)

  test("Dialogue cancellation releases the active request", function()
    local runner, _, dialogue = services()
    runner:start("cancel-dialogue", function()
      Commands.text("crystal.text.test.waiting")
    end)
    truthy(runner:cancel("cancel-dialogue"))
    equal(dialogue.active, nil)
    truthy(dialogue.transcript[1].cancelled)
  end)

  test("ScriptState snapshots are isolated and validated", function()
    local state = ScriptState.new()
    state:setFlag("crystal.story.started")
    state:setVariable("player.name", "KRIS")
    local snapshot = state:snapshot()
    snapshot.flags["crystal.story.started"] = nil
    truthy(state:hasFlag("crystal.story.started"))

    raises(function()
      state:setVariable("player.party", {})
    end, "must be booleans")
    raises(function()
      ScriptState.new({ flags = { ["bad flag"] = true } })
    end, "stable ID")
  end)

  test("DialogueService rejects unavailable choices", function()
    local _, _, dialogue = services()
    dialogue:choice({
      id = "crystal.choice.test",
      options = {
        {
          id = "common.choice.yes",
          textId = "common.text.yes",
        },
      },
    })
    raises(function()
      dialogue:choose("common.choice.no")
    end, "does not contain")
  end)
end
