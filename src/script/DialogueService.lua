local ScriptRunner = require("src.script.ScriptRunner")

local DialogueService = {}
DialogueService.__index = DialogueService

local function fail(message, level)
  error("dialogue service: " .. message, level or 3)
end

local function validId(value)
  if type(value) ~= "string"
      or not value:find(".", 1, true)
      or value:sub(1, 1) == "."
      or value:sub(-1) == "."
      or value:find("..", 1, true) then
    return false
  end
  for segment in value:gmatch("[^.]+") do
    if not segment:match("^[a-z][a-z0-9_]*$") then return false end
  end
  return true
end

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values or {}) do result[index] = value end
  return result
end

local function validateText(arguments)
  if not validId(arguments.id) then
    fail("text id must be a dotted lowercase stable ID")
  end
  if arguments.substitutions ~= nil
      and type(arguments.substitutions) ~= "table" then
    fail("text substitutions must be a table")
  end
end

local function validateChoice(arguments)
  if not validId(arguments.id) then
    fail("choice id must be a dotted lowercase stable ID")
  end
  if type(arguments.options) ~= "table" or #arguments.options < 1 then
    fail("choices must provide at least one option")
  end
  local seen = {}
  for _, option in ipairs(arguments.options) do
    if type(option) ~= "table"
        or not validId(option.id)
        or not validId(option.textId) then
      fail("choice options require stable id and textId values")
    end
    if seen[option.id] then fail("choice option IDs must be unique") end
    seen[option.id] = true
  end
end

function DialogueService.new()
  return setmetatable({
    active = nil,
    transcript = {},
  }, DialogueService)
end

function DialogueService:_begin(event)
  if self.active then fail("another dialogue request is already active", 2) end
  self.active = event
  self.transcript[#self.transcript + 1] = event
  return ScriptRunner.wait(
    function()
      return event.resolved, event.result
    end,
    function()
      event.cancelled = true
      if self.active == event then self.active = nil end
    end
  )
end

function DialogueService:text(arguments)
  validateText(arguments)
  return self:_begin({
    kind = "text",
    id = arguments.id,
    substitutions = arguments.substitutions or {},
    resolved = false,
  })
end

function DialogueService:choice(arguments)
  validateChoice(arguments)
  return self:_begin({
    kind = "choice",
    id = arguments.id,
    options = copyArray(arguments.options),
    resolved = false,
  })
end

function DialogueService:advance()
  local event = self.active
  if not event or event.kind ~= "text" then return false end
  event.resolved = true
  event.result = true
  self.active = nil
  return true
end

function DialogueService:choose(optionId)
  local event = self.active
  if not event or event.kind ~= "choice" then return false end
  for _, option in ipairs(event.options) do
    if option.id == optionId then
      event.resolved = true
      event.result = optionId
      self.active = nil
      return true
    end
  end
  fail("choice does not contain option " .. tostring(optionId), 2)
end

return DialogueService
