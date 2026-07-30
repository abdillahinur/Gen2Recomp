local ScriptDefinition = require("src.script.ScriptDefinition")

local ScriptCatalog = {}
ScriptCatalog.__index = ScriptCatalog

local COVERAGE_KINDS = {
  "callbacks",
  "scenes",
  "coordEvents",
  "bgEvents",
  "objects",
}

local function fail(message, level)
  error("script catalog: " .. message, level or 3)
end

local function set(values)
  local result = {}
  for _, value in ipairs(values or {}) do result[value] = true end
  return result
end

local function validateMapBehavior(definition)
  if definition.kind ~= "map" then return end
  for _, kind in ipairs(COVERAGE_KINDS) do
    local declared = set(definition.coverage[kind])
    local behavior = definition.behavior[kind]
    if type(behavior) ~= "table" then
      fail(definition.id .. " is missing behavior." .. kind)
    end
    for id in pairs(declared) do
      if type(behavior[id]) ~= "function" then
        fail(definition.id .. " does not implement " .. id)
      end
    end
    for id, implementation in pairs(behavior) do
      if not declared[id] then
        fail(definition.id .. " implements undeclared ID " .. tostring(id))
      end
      if type(implementation) ~= "function" then
        fail(definition.id .. " behavior " .. id .. " is not a function")
      end
    end
  end
end

local function validateActors(definition)
  if definition.actors == nil then return end
  if type(definition.actors) ~= "table" then
    fail(definition.id .. " actors must be an array")
  end
  local maps = set(definition.maps)
  local seen = {}
  for _, actor in ipairs(definition.actors) do
    if type(actor) ~= "table"
        or type(actor.id) ~= "string"
        or not maps[actor.mapId]
        or type(actor.objectId) ~= "number"
        or actor.objectId < 1
        or actor.objectId % 1 ~= 0 then
      fail(definition.id .. " has an invalid actor binding")
    end
    local key = actor.mapId .. ":" .. actor.objectId
    if seen[actor.id] or seen[key] then
      fail(definition.id .. " has a duplicate actor binding")
    end
    seen[actor.id] = true
    seen[key] = true
  end
end

function ScriptCatalog.new(definitions)
  local self = setmetatable({
    definitions = {},
    byId = {},
    byMap = {},
    coverageIds = {},
  }, ScriptCatalog)

  for _, definition in ipairs(definitions or {}) do
    ScriptDefinition.validate(definition)
    validateMapBehavior(definition)
    validateActors(definition)
    if self.byId[definition.id] then
      fail("duplicate script ID " .. definition.id, 2)
    end
    self.definitions[#self.definitions + 1] = definition
    self.byId[definition.id] = definition
    for _, mapId in ipairs(definition.maps) do
      if self.byMap[mapId] then
        fail("multiple scripts claim map " .. mapId, 2)
      end
      self.byMap[mapId] = definition
    end
    for _, kind in ipairs(COVERAGE_KINDS) do
      for _, id in ipairs(definition.coverage[kind]) do
        if self.coverageIds[id] then
          fail("duplicate coverage ID " .. id, 2)
        end
        self.coverageIds[id] = {
          definition = definition,
          kind = kind,
        }
      end
    end
  end
  table.sort(self.definitions, function(left, right)
    return left.id < right.id
  end)
  return self
end

function ScriptCatalog.load(moduleNames)
  moduleNames = moduleNames or require("data.scripts.catalog")
  local definitions = {}
  for _, moduleName in ipairs(moduleNames) do
    definitions[#definitions + 1] = require(moduleName)
  end
  return ScriptCatalog.new(definitions)
end

function ScriptCatalog:get(id)
  return self.byId[id]
end

function ScriptCatalog:forMap(mapId)
  return self.byMap[mapId]
end

function ScriptCatalog:all()
  return self.definitions
end

return ScriptCatalog
