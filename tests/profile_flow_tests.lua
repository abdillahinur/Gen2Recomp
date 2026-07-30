return function(test, equal, truthy, raises)
  local ClockSetupService =
    require("src.script.ClockSetupService")
  local IntroductionSession =
    require("src.script.IntroductionSession")
  local NameEntryService = require("src.script.NameEntryService")

  local introduction =
    require("data.scripts.crystal.flows.introduction")

  local function session()
    return IntroductionSession.new(introduction, {
      nameOptions = {
        presets = {
          male = {
            { id = "test.name.male_one", value = "AL" },
          },
          female = {
            { id = "test.name.female_one", value = "KIM" },
          },
        },
      },
    })
  end

  local function finishText(sessionValue)
    while sessionValue.dialogue.active do
      equal(sessionValue.dialogue.active.kind, "text")
      sessionValue.dialogue:advance()
      sessionValue:update(0)
    end
  end

  local function reachName(sessionValue, genderId, hour, minute)
    sessionValue:start()
    equal(sessionValue.dialogue.active.kind, "choice")
    sessionValue.dialogue:choose(genderId)
    sessionValue:update(0)
    truthy(sessionValue.clock.active)
    sessionValue.clock:setTime(hour, minute)
    sessionValue.clock:confirm()
    sessionValue:update(0)
    finishText(sessionValue)
    truthy(sessionValue.names.active)
  end

  test("Introduction session completes a preset male-name route", function()
    local value = session()
    reachName(value, "crystal.profile.gender.boy", 9, 15)
    truthy(value.names:choosePreset("test.name.male_one"))
    value:update(0)
    finishText(value)
    equal(value.task.state, "completed")
    equal(value.state:getVariable("player.gender"), "male")
    equal(value.state:getVariable("player.name"), "AL")
    equal(value.state:getVariable("clock.hour"), 9)
    equal(value.state:getVariable("clock.minute"), 15)
  end)

  test("Introduction session completes a custom female-name route", function()
    local value = session()
    reachName(value, "crystal.profile.gender.girl", 22, 45)
    truthy(value.names:beginCustom())
    truthy(value.names:setCustom("NOVA"))
    truthy(value.names:submitCustom())
    value:update(0)
    finishText(value)
    equal(value.task.state, "completed")
    equal(value.task.result.gender, "female")
    equal(value.task.result.name, "NOVA")
    truthy(value.state:hasFlag(
      "crystal.story.introduction_complete"))
  end)

  test("Clock and name services validate user-controlled values", function()
    local clock = ClockSetupService.new()
    clock:begin()
    raises(function() clock:setTime(24, 0) end, "hour must")
    raises(function() clock:setTime(10, 60) end, "minute must")

    local names = NameEntryService.new()
    names:begin({ gender = "male" })
    names:beginCustom()
    raises(function() names:submitCustom() end, "cannot be empty")
    raises(function() names:setCustom("TOO-LONG") end, "exceeds 7")
  end)

  test("Introduction cancellation releases active profile UI", function()
    local value = session()
    value:start()
    truthy(value:cancel("return to title"))
    equal(value.task.state, "cancelled")
    equal(value.dialogue.active, nil)
    equal(value.task.cancellationReason, "return to title")
  end)
end
