local RtcPersistence = {}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end

function RtcPersistence.reconcile(snapshot, savedAt, now)
  local result = copy(snapshot)
  local elapsed = math.max(0, math.floor(now - savedAt))
  local clock = result.clock or {}
  local total = (clock.hour or 0) * 3600
    + (clock.minute or 0) * 60 + elapsed
  local days = math.floor(total / 86400)
  local withinDay = total % 86400
  clock.hour = math.floor(withinDay / 3600)
  clock.minute = math.floor(withinDay % 3600 / 60)
  if clock.weekday ~= nil then
    clock.weekday = (clock.weekday + days) % 7
  end
  result.clock = clock
  return result, {
    elapsedSeconds = elapsed,
    hostClockMovedBackward = now < savedAt,
  }
end

return RtcPersistence
