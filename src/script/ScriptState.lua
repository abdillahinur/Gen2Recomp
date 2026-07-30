local ScriptState = {}
ScriptState.__index = ScriptState

local function fail(message, level)
  error("script state: " .. message, level or 3)
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

local function requireId(value, field)
  if not validId(value) then
    fail(field .. " must be a dotted lowercase stable ID", 3)
  end
end

local function validScalar(value)
  local kind = type(value)
  return value == nil
    or kind == "boolean"
    or kind == "number"
    or kind == "string"
end

local function copy(values)
  local result = {}
  for key, value in pairs(values or {}) do
    result[key] = value
  end
  return result
end

function ScriptState.new(snapshot)
  snapshot = snapshot or {}
  local self = setmetatable({
    flags = copy(snapshot.flags),
    scenes = copy(snapshot.scenes),
    variables = copy(snapshot.variables),
  }, ScriptState)
  for id, value in pairs(self.flags) do
    requireId(id, "flag")
    if value ~= true then fail("snapshot flags must equal true", 2) end
  end
  for scope, scene in pairs(self.scenes) do
    requireId(scope, "scene scope")
    requireId(scene, "scene")
  end
  for id, value in pairs(self.variables) do
    requireId(id, "variable")
    if not validScalar(value) then
      fail("snapshot variables must be scalar values", 2)
    end
  end
  return self
end

function ScriptState:hasFlag(id)
  requireId(id, "flag")
  return self.flags[id] == true
end

function ScriptState:setFlag(id, enabled)
  requireId(id, "flag")
  if enabled == false then
    self.flags[id] = nil
  else
    self.flags[id] = true
  end
end

function ScriptState:getScene(scope)
  requireId(scope, "scene scope")
  return self.scenes[scope]
end

function ScriptState:setScene(scope, scene)
  requireId(scope, "scene scope")
  if scene ~= nil then requireId(scene, "scene") end
  self.scenes[scope] = scene
end

function ScriptState:getVariable(id, default)
  requireId(id, "variable")
  local value = self.variables[id]
  if value == nil then return default end
  return value
end

function ScriptState:setVariable(id, value)
  requireId(id, "variable")
  if not validScalar(value) then
    fail("variable values must be booleans, numbers, strings, or nil", 2)
  end
  self.variables[id] = value
end

function ScriptState:snapshot()
  return {
    flags = copy(self.flags),
    scenes = copy(self.scenes),
    variables = copy(self.variables),
  }
end

return ScriptState
