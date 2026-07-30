local TimeOfDay = {}
TimeOfDay.__index = TimeOfDay

local FORCED_MODES = {
  [1] = "day",
  [2] = "night",
  [3] = "morning",
  [4] = "dark",
}

function TimeOfDay.new(options)
  options = options or {}
  return setmetatable({
    clock = options.clock or os.date,
    fixedPeriod = options.fixedPeriod,
  }, TimeOfDay)
end

function TimeOfDay:period()
  if self.fixedPeriod then
    return self.fixedPeriod
  end
  local value = self.clock("*t")
  local hour = type(value) == "table" and value.hour or 12
  if hour >= 4 and hour < 10 then
    return "morning"
  elseif hour >= 10 and hour < 18 then
    return "day"
  end
  return "night"
end

function TimeOfDay:forMap(paletteModeId)
  return FORCED_MODES[paletteModeId] or self:period()
end

function TimeOfDay:setFixedPeriod(period)
  if period ~= nil
      and period ~= "morning"
      and period ~= "day"
      and period ~= "night"
      and period ~= "dark" then
    error("invalid time-of-day period", 2)
  end
  self.fixedPeriod = period
end

return TimeOfDay
