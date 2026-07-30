return function(test, equal, truthy, raises)
  local Commands = require("src.script.Commands")
  local ScriptRunner = require("src.script.ScriptRunner")

  test("ScriptRunner dispatches commands and returns their values", function()
    local runner = ScriptRunner.new()
    runner:register("test.echo", function(arguments)
      return arguments.value
    end)
    local task = runner:start("echo", function()
      local value = Commands.request("test.echo", { value = "native" })
      return value .. " lua"
    end)
    equal(task.state, "completed")
    equal(task.result, "native lua")
    truthy(runner:isFinished("echo"))
    truthy(not runner:isBusy())
  end)

  test("ScriptRunner advances asynchronous waits deterministically", function()
    local runner = ScriptRunner.new()
    runner:register("test.delay", function(arguments)
      local remaining = arguments.seconds
      return ScriptRunner.wait(function(_, dt)
        remaining = remaining - dt
        return remaining <= 0, "finished"
      end)
    end)
    local task = runner:start("delay", function()
      return Commands.request("test.delay", { seconds = 0.5 })
    end)
    equal(task.state, "waiting")
    runner:update(0.2)
    equal(task.state, "waiting")
    runner:update(0.3)
    equal(task.state, "completed")
    equal(task.result, "finished")
  end)

  test("ScriptRunner cancels pending commands cleanly", function()
    local cancelled = false
    local runner = ScriptRunner.new()
    runner:register("test.wait", function()
      return ScriptRunner.wait(
        function() return false end,
        function() cancelled = true end
      )
    end)
    local task = runner:start("cancel", function()
      Commands.request("test.wait")
    end)
    truthy(runner:cancel("cancel", "map changed"))
    equal(task.state, "cancelled")
    equal(task.cancellationReason, "map changed")
    truthy(cancelled)
    truthy(not runner:cancel("cancel"))
  end)

  test("ScriptRunner isolates script and command failures", function()
    local runner = ScriptRunner.new()
    local missing = runner:start("missing", function()
      Commands.request("test.missing")
    end)
    equal(missing.state, "failed")
    truthy(missing.error:match("no handler"))

    runner:register("test.fail", function()
      error("handler exploded")
    end)
    local failed = runner:start("failed", function()
      Commands.request("test.fail")
    end)
    equal(failed.state, "failed")
    truthy(failed.error:match("handler exploded"))
  end)

  test("ScriptRunner rejects malformed yields and runaway scripts", function()
    local runner = ScriptRunner.new({ maxImmediateResumes = 3 })
    local malformed = runner:start("malformed", function()
      coroutine.yield({ command = "untyped" })
    end)
    equal(malformed.state, "failed")
    truthy(malformed.error:match("invalid command request"))

    runner:register("test.again", function() return true end)
    local runaway = runner:start("runaway", function()
      while true do Commands.request("test.again") end
    end)
    equal(runaway.state, "failed")
    truthy(runaway.error:match("immediate command limit"))
  end)

  test("Commands require a script coroutine", function()
    raises(function()
      Commands.request("test.echo")
    end, "only run inside")
  end)
end
