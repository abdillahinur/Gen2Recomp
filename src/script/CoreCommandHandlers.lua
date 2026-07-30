local CoreCommandHandlers = {}

local ScriptRunner = require("src.script.ScriptRunner")

function CoreCommandHandlers.install(runner, services)
  local state = assert(services.state, "script state service is required")
  local dialogue =
    assert(services.dialogue, "dialogue service is required")

  runner:register("state.flag.get", function(arguments)
    return state:hasFlag(arguments.id)
  end)
  runner:register("state.flag.set", function(arguments)
    state:setFlag(arguments.id, true)
  end)
  runner:register("state.flag.clear", function(arguments)
    state:setFlag(arguments.id, false)
  end)
  runner:register("state.scene.get", function(arguments)
    return state:getScene(arguments.scope)
  end)
  runner:register("state.scene.set", function(arguments)
    state:setScene(arguments.scope, arguments.scene)
  end)
  runner:register("state.variable.get", function(arguments)
    return state:getVariable(arguments.id, arguments.default)
  end)
  runner:register("state.variable.set", function(arguments)
    state:setVariable(arguments.id, arguments.value)
  end)
  runner:register("ui.text", function(arguments)
    return dialogue:text(arguments)
  end)
  runner:register("ui.choice", function(arguments)
    return dialogue:choice(arguments)
  end)
  runner:register("system.wait", function(arguments)
    local remaining = arguments.seconds
    if type(remaining) ~= "number" or remaining < 0 then
      error("wait seconds must be a non-negative number")
    end
    return ScriptRunner.wait(function(_, dt)
      remaining = remaining - dt
      return remaining <= 0, true
    end)
  end)
end

return CoreCommandHandlers
