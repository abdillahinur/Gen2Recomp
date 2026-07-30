return function(test, equal, truthy)
  local CoreCommandHandlers =
    require("src.script.CoreCommandHandlers")
  local DialogueService = require("src.script.DialogueService")
  local ScriptDefinition = require("src.script.ScriptDefinition")
  local ScriptRunner = require("src.script.ScriptRunner")
  local ScriptState = require("src.script.ScriptState")
  local gym = require("data.scripts.crystal.maps.violet_gym")

  local function setup(won)
    local state = ScriptState.new()
    local dialogue = DialogueService.new()
    local runner = ScriptRunner.new()
    local commands = {}
    CoreCommandHandlers.install(runner, {
      state = state,
      dialogue = dialogue,
    })
    for _, name in ipairs({
      "actor.face", "audio.sfx.play", "inventory.item.give",
    }) do
      local commandName = name
      runner:register(commandName, function(arguments)
        commands[#commands + 1] = {
          name = commandName, arguments = arguments,
        }
        return true
      end)
    end
    runner:register("gameplay.battle", function(arguments)
      commands[#commands + 1] = {
        name = "gameplay.battle", arguments = arguments,
      }
      return {
        outcome = won == false and "opponent_win" or "player_win",
        won = won ~= false,
      }
    end)
    return runner, state, dialogue, commands
  end

  local function drive(runner, dialogue, task)
    for _ = 1, 100 do
      if task.state == "completed" or task.state == "failed" then break end
      if dialogue.active then dialogue:advance() end
      runner:update(1)
    end
    equal(task.state, "completed")
  end

  test("Violet Gym definition validates complete interactions", function()
    equal(ScriptDefinition.validate(gym), gym)
    equal(gym.maps[1], "10:7")
    equal(#gym.coverage.objects, 4)
    equal(#gym.coverage.bgEvents, 2)
  end)

  test("Falkner victory grants Zephyr Badge and TM31", function()
    local runner, state, dialogue, commands = setup(true)
    local task = runner:start(
      "falkner",
      gym.behavior.objects["crystal.violet_gym.object.falkner"]
    )
    drive(runner, dialogue, task)
    truthy(state:hasFlag("crystal.story.beat_falkner"))
    truthy(state:hasFlag("crystal.badge.zephyr"))
    truthy(state:hasFlag("crystal.violet_gym.got_tm31"))
    truthy(state:hasFlag("crystal.trainer.defeated.f1019"))
    truthy(state:hasFlag("crystal.trainer.defeated.f1020"))
    local battle, tm
    for _, command in ipairs(commands) do
      if command.name == "gameplay.battle" then battle = command end
      if command.name == "inventory.item.give" then tm = command end
    end
    equal(battle.arguments.opponentId, "crystal.trainer.01.001")
    equal(tm.arguments.itemId, "crystal.item.tm31")
  end)

  test("Falkner loss does not grant badge progression", function()
    local runner, state, dialogue = setup(false)
    local task = runner:start(
      "falkner-loss",
      gym.behavior.objects["crystal.violet_gym.object.falkner"]
    )
    drive(runner, dialogue, task)
    truthy(not state:hasFlag("crystal.badge.zephyr"))
    truthy(not state:hasFlag("crystal.violet_gym.got_tm31"))
  end)
end
