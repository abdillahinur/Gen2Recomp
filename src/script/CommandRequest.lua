local CommandRequest = {}

CommandRequest.PROTOCOL = "gen2recomp.command.v1"

local function validName(name)
  if type(name) ~= "string"
      or not name:find(".", 1, true)
      or name:sub(1, 1) == "."
      or name:sub(-1) == "."
      or name:find("..", 1, true) then
    return false
  end
  for segment in name:gmatch("[^.]+") do
    if not segment:match("^[a-z][a-z0-9_]*$") then
      return false
    end
  end
  return true
end

function CommandRequest.new(name, arguments)
  if not validName(name) then
    error("command name must be a dotted lowercase stable ID", 2)
  end
  if arguments ~= nil and type(arguments) ~= "table" then
    error("command arguments must be a table or nil", 2)
  end
  return {
    protocol = CommandRequest.PROTOCOL,
    name = name,
    arguments = arguments or {},
  }
end

function CommandRequest.validate(value)
  return type(value) == "table"
    and value.protocol == CommandRequest.PROTOCOL
    and validName(value.name)
    and type(value.arguments) == "table"
end

return CommandRequest
