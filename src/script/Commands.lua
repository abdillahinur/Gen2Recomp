local CommandRequest = require("src.script.CommandRequest")

local Commands = {}

function Commands.request(name, arguments)
  local thread, isMain = coroutine.running()
  if not thread or isMain then
    error("script commands can only run inside a script coroutine", 2)
  end
  return coroutine.yield(CommandRequest.new(name, arguments))
end

function Commands.hasFlag(id)
  return Commands.request("state.flag.get", { id = id })
end

function Commands.setFlag(id)
  return Commands.request("state.flag.set", { id = id })
end

function Commands.clearFlag(id)
  return Commands.request("state.flag.clear", { id = id })
end

function Commands.getScene(scope)
  return Commands.request("state.scene.get", { scope = scope })
end

function Commands.setScene(scope, scene)
  return Commands.request("state.scene.set", {
    scope = scope,
    scene = scene,
  })
end

function Commands.getVariable(id, default)
  return Commands.request("state.variable.get", {
    id = id,
    default = default,
  })
end

function Commands.setVariable(id, value)
  return Commands.request("state.variable.set", {
    id = id,
    value = value,
  })
end

function Commands.text(id, substitutions)
  return Commands.request("ui.text", {
    id = id,
    substitutions = substitutions,
  })
end

function Commands.choice(id, options)
  return Commands.request("ui.choice", {
    id = id,
    options = options,
  })
end

return Commands
