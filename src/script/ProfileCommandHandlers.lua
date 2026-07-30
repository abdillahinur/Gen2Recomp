local ProfileCommandHandlers = {}

function ProfileCommandHandlers.install(runner, services)
  local clock = assert(services.clock, "clock setup service is required")
  local names = assert(services.names, "name entry service is required")
  runner:register("system.clock.setup", function()
    return clock:begin()
  end)
  runner:register("ui.name.select", function(arguments)
    return names:begin(arguments)
  end)
end

return ProfileCommandHandlers
