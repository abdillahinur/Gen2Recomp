local Provenance = require("data.scripts.Provenance")

local ScriptDefinition = {}

local COVERAGE_KINDS = {
  callbacks = true,
  scenes = true,
  coordEvents = true,
  bgEvents = true,
  objects = true,
}

local VALID_GAMES = {
  common = true,
  crystal = true,
  gold = true,
  silver = true,
}

local VALID_KINDS = {
  flow = true,
  map = true,
  shared = true,
}

local function fail(message, level)
  error("invalid script definition: " .. message, level or 3)
end

local function isArray(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
  end
  return count == #value
end

local function requireIdentifier(value, field)
  if type(value) ~= "string" or not value:find(".", 1, true) then
    fail(field .. " must be a dotted lowercase stable ID")
  end
  local count = 0
  for segment in value:gmatch("[^.]+") do
    count = count + 1
    if not segment:match("^[a-z][a-z0-9_]*$") then
      fail(field .. " must be a dotted lowercase stable ID")
    end
  end
  if count < 2
      or value:sub(1, 1) == "."
      or value:sub(-1) == "."
      or value:find("..", 1, true) then
    fail(field .. " must be a dotted lowercase stable ID")
  end
end

local function requireIdArray(values, field)
  if not isArray(values) then
    fail(field .. " must be an array")
  end
  local seen = {}
  for index, value in ipairs(values) do
    requireIdentifier(value, field .. "[" .. index .. "]")
    if seen[value] then
      fail(field .. " contains duplicate ID " .. value)
    end
    seen[value] = true
  end
end

local function validateMaps(definition)
  if not isArray(definition.maps) then
    fail("maps must be an array")
  end
  if definition.kind == "map" and #definition.maps == 0 then
    fail("map scripts must declare at least one map")
  end
  local seen = {}
  for _, mapId in ipairs(definition.maps) do
    if type(mapId) ~= "string"
        or not mapId:match("^[1-9][0-9]*:[1-9][0-9]*$") then
      fail("map IDs must use the stable group:map form")
    end
    if seen[mapId] then
      fail("maps contains duplicate ID " .. mapId)
    end
    seen[mapId] = true
  end
end

local function validatePath(path)
  if type(path) ~= "string"
      or path == ""
      or path:sub(1, 1) == "/"
      or path:find("\\", 1, true)
      or path:find("..", 1, true)
      or not path:match("%.asm$") then
    fail("reference paths must be safe repository-relative .asm paths")
  end
end

local function validateCitation(citation, game, index)
  if type(citation) ~= "table" then
    fail("provenance[" .. index .. "] must be a citation")
  end
  local source = Provenance.source(game)
  if not source then
    fail("no pinned provenance source exists for " .. game)
  end
  if citation.source ~= source.id then
    fail("provenance[" .. index .. "] has the wrong source")
  end
  if citation.revision ~= source.revision then
    fail("provenance[" .. index .. "] is not pinned to the source revision")
  end
  validatePath(citation.path)
  if not isArray(citation.labels) or #citation.labels == 0 then
    fail("provenance[" .. index .. "] must cite at least one label")
  end
  for _, label in ipairs(citation.labels) do
    if type(label) ~= "string"
        or not label:match("^[A-Za-z_][A-Za-z0-9_.]*$") then
      fail("provenance[" .. index .. "] contains an invalid label")
    end
  end
  if type(citation.notes) ~= "string" or citation.notes == "" then
    fail("provenance[" .. index .. "] must explain the behavioral use")
  end
end

local function validateProvenance(definition)
  if definition.game == "common" then
    if definition.provenance ~= nil
        and (not isArray(definition.provenance)
          or #definition.provenance > 0) then
      fail("common scripts cannot claim game-reference provenance")
    end
    return
  end
  if not isArray(definition.provenance) or #definition.provenance == 0 then
    fail("game behavior requires at least one provenance citation")
  end
  for index, citation in ipairs(definition.provenance) do
    validateCitation(citation, definition.game, index)
  end
end

local function validateCoverage(definition)
  if type(definition.coverage) ~= "table" then
    fail("coverage must be a table")
  end
  for key in pairs(definition.coverage) do
    if not COVERAGE_KINDS[key] then
      fail("coverage contains unknown kind " .. tostring(key))
    end
  end
  for kind in pairs(COVERAGE_KINDS) do
    requireIdArray(definition.coverage[kind] or {},
      "coverage." .. kind)
  end
end

function ScriptDefinition.validate(definition)
  if type(definition) ~= "table" then
    fail("module must return a table", 2)
  end
  if definition.schema ~= 1 then
    fail("schema must equal 1", 2)
  end
  requireIdentifier(definition.id, "id")
  if not VALID_GAMES[definition.game] then
    fail("game must be common, crystal, gold, or silver", 2)
  end
  if not VALID_KINDS[definition.kind] then
    fail("kind must be flow, map, or shared", 2)
  end
  validateMaps(definition)
  validateProvenance(definition)
  validateCoverage(definition)
  if type(definition.behavior) ~= "table" then
    fail("behavior must be a table", 2)
  end
  return definition
end

return ScriptDefinition
