return function(test, equal, truthy)
  local ClockSetupService =
    require("src.script.ClockSetupService")
  local DialogueService = require("src.script.DialogueService")
  local NameEntryService = require("src.script.NameEntryService")
  local PresentationController =
    require("src.ui.PresentationController")

  local function input(action)
    return {
      wasPressed = function(_, candidate)
        return action == candidate
      end,
    }
  end

  test("presentation controller advances text and visible choices", function()
    local dialogue = DialogueService.new()
    local controller =
      PresentationController.new({ dialogue = dialogue })
    dialogue:text({ id = "test.text.hello" })
    equal(controller:model().kind, "text")
    equal(controller:model().text, "TEXT · HELLO")
    controller:update(input("confirm"))
    equal(dialogue.active, nil)

    dialogue:choice({
      id = "test.choice.route",
      options = {
        { id = "test.option.one", textId = "common.text.yes" },
        { id = "test.option.two", textId = "common.text.no" },
      },
    })
    controller:update(input("down"))
    local model = controller:model()
    equal(model.kind, "choice")
    equal(model.selected, 2)
    equal(model.options[2], "NO")
    controller:update(input("confirm"))
    equal(dialogue.active, nil)
  end)

  test("presentation controller edits and confirms the clock", function()
    local clock = ClockSetupService.new({
      defaultHour = 10,
      defaultMinute = 30,
    })
    local controller = PresentationController.new({ clock = clock })
    clock:begin()
    controller:update(input("up"))
    equal(clock.active.hour, 11)
    controller:update(input("right"))
    controller:update(input("down"))
    equal(clock.active.minute, 29)
    controller:update(input("confirm"))
    equal(clock.active, nil)
  end)

  test("presentation controller supports custom on-screen names", function()
    local names = NameEntryService.new()
    local controller = PresentationController.new({ names = names })
    names:begin({ gender = "female" })
    controller:update(input("confirm"))
    equal(names.active.stage, "custom")
    controller:update(input("confirm"))
    equal(names.active.custom, "A")
    for _ = 1, 3 do controller:update(input("down")) end
    for _ = 1, 6 do controller:update(input("right")) end
    equal(controller:model().keyboard[4][7], "END")
    controller:update(input("confirm"))
    equal(names.active, nil)
    equal(names.history[1].result, "A")
  end)

  test("introduction state completes through visible requests", function()
    local IntroductionState =
      require("src.states.IntroductionState")
    local completed
    local state = IntroductionState.new({
      nameOptions = {
        presets = {
          male = { { id = "test.name.al", value = "AL" } },
        },
      },
      onComplete = function(result) completed = result end,
    })
    state:enter()
    state:update(0, input("confirm"))
    state:update(0, input())
    truthy(state.session.clock.active)
    state:update(0, input("confirm"))
    state:update(0, input())

    local guard = 0
    while not state.session.names.active do
      guard = guard + 1
      if guard > 20 then error("introduction did not reach naming") end
      truthy(state.session.dialogue.active)
      state:update(0, input("confirm"))
      state:update(0, input())
    end
    state:update(0, input("confirm"))
    state:update(0, input())
    truthy(state.session.dialogue.active)
    state:update(0, input("confirm"))
    state:update(0, input())
    equal(completed.name, "AL")
    equal(state.session.task.state, "completed")
  end)
end
