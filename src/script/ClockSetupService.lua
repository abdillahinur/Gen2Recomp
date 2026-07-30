local ScriptRunner = require("src.script.ScriptRunner")

local ClockSetupService = {}
ClockSetupService.__index = ClockSetupService

local function requireInteger(value, minimum, maximum, field)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < minimum or value > maximum then
    error(("clock setup: %s must be an integer from %d to %d")
      :format(field, minimum, maximum), 3)
  end
end

function ClockSetupService.new(options)
  options = options or {}
  return setmetatable({
    defaultHour = options.defaultHour or 10,
    defaultMinute = options.defaultMinute or 0,
    active = nil,
    history = {},
  }, ClockSetupService)
end

function ClockSetupService:begin()
  if self.active then error("clock setup: setup is already active", 2) end
  local request = {
    hour = self.defaultHour,
    minute = self.defaultMinute,
    resolved = false,
  }
  requireInteger(request.hour, 0, 23, "default hour")
  requireInteger(request.minute, 0, 59, "default minute")
  self.active = request
  self.history[#self.history + 1] = request
  return ScriptRunner.wait(
    function()
      return request.resolved, request.result
    end,
    function()
      request.cancelled = true
      if self.active == request then self.active = nil end
    end
  )
end

function ClockSetupService:setTime(hour, minute)
  if not self.active then return false end
  requireInteger(hour, 0, 23, "hour")
  requireInteger(minute, 0, 59, "minute")
  self.active.hour = hour
  self.active.minute = minute
  return true
end

function ClockSetupService:confirm()
  local request = self.active
  if not request then return false end
  request.resolved = true
  request.result = {
    hour = request.hour,
    minute = request.minute,
  }
  self.active = nil
  return true
end

return ClockSetupService
