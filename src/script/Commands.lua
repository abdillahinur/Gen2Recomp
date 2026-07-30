local CommandRequest = require("src.script.CommandRequest")

local Commands = {}

function Commands.request(name, arguments)
  local thread, isMain = coroutine.running()
  if not thread or isMain then
    error("script commands can only run inside a script coroutine", 2)
  end
  return coroutine.yield(CommandRequest.new(name, arguments))
end

return Commands
