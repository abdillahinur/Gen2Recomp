local ScriptRunner = require("src.script.ScriptRunner")

local NameEntryService = {}
NameEntryService.__index = NameEntryService

local function fail(message, level)
  error("name entry: " .. message, level or 3)
end

local function copyPresets(values)
  local result = { male = {}, female = {} }
  for _, gender in ipairs({ "male", "female" }) do
    for index, preset in ipairs(values[gender] or {}) do
      if type(preset) ~= "table"
          or type(preset.id) ~= "string"
          or type(preset.value) ~= "string" then
        fail("presets require string id and value fields", 3)
      end
      result[gender][index] = {
        id = preset.id,
        value = preset.value,
      }
    end
  end
  return result
end

function NameEntryService.new(options)
  options = options or {}
  local maximumLength = options.maximumLength or 7
  if type(maximumLength) ~= "number"
      or maximumLength < 1
      or maximumLength % 1 ~= 0 then
    fail("maximumLength must be a positive integer", 2)
  end
  return setmetatable({
    maximumLength = maximumLength,
    presets = copyPresets(options.presets or {}),
    active = nil,
    history = {},
  }, NameEntryService)
end

function NameEntryService:_validate(value)
  if type(value) ~= "string" or value == "" then
    fail("name cannot be empty", 3)
  end
  if #value > self.maximumLength then
    fail("name exceeds " .. self.maximumLength .. " characters", 3)
  end
  if value:find("[%z\1-\31\127]") then
    fail("name contains control characters", 3)
  end
  return value
end

function NameEntryService:begin(arguments)
  if self.active then fail("name selection is already active", 2) end
  local gender = arguments.gender
  if gender ~= "male" and gender ~= "female" then
    fail("gender must be male or female", 2)
  end
  local request = {
    gender = gender,
    stage = "choices",
    presets = self.presets[gender],
    custom = "",
    resolved = false,
  }
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

function NameEntryService:choosePreset(id)
  local request = self.active
  if not request or request.stage ~= "choices" then return false end
  for _, preset in ipairs(request.presets) do
    if preset.id == id then
      request.result = self:_validate(preset.value)
      request.resolved = true
      self.active = nil
      return true
    end
  end
  fail("preset is unavailable: " .. tostring(id), 2)
end

function NameEntryService:beginCustom()
  local request = self.active
  if not request or request.stage ~= "choices" then return false end
  request.stage = "custom"
  request.custom = ""
  return true
end

function NameEntryService:setCustom(value)
  local request = self.active
  if not request or request.stage ~= "custom" then return false end
  if type(value) ~= "string" then fail("custom name must be a string", 2) end
  if #value > self.maximumLength then
    fail("name exceeds " .. self.maximumLength .. " characters", 2)
  end
  if value:find("[%z\1-\31\127]") then
    fail("name contains control characters", 2)
  end
  request.custom = value
  return true
end

function NameEntryService:submitCustom()
  local request = self.active
  if not request or request.stage ~= "custom" then return false end
  request.result = self:_validate(request.custom)
  request.resolved = true
  self.active = nil
  return true
end

function NameEntryService:backToChoices()
  local request = self.active
  if not request or request.stage ~= "custom" then return false end
  request.stage = "choices"
  request.custom = ""
  return true
end

return NameEntryService
