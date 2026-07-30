local InventoryService = require("src.script.InventoryService")
local PartyService = require("src.script.PartyService")
local PhoneService = require("src.script.PhoneService")
local ScriptState = require("src.script.ScriptState")
local StorageService = require("src.game.StorageService")

local GameSession = {}
GameSession.__index = GameSession

local SCHEMA = 1

local function fail(message, level)
  error("game session: " .. message, level or 3)
end

local function requireInteger(value, minimum, maximum, field)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < minimum or value > maximum then
    fail(("%s must be an integer from %d to %d")
      :format(field, minimum, maximum), 3)
  end
  return value
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value or {}) do result[key] = copy(item) end
  return result
end

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values or {}) do
    result[index] = type(value) == "table" and copy(value) or value
  end
  return result
end

local function sortedSet(values)
  local result = {}
  for id, enabled in pairs(values or {}) do
    if enabled then result[#result + 1] = id end
  end
  table.sort(result)
  return result
end

local function setFromArray(values, field)
  local result = {}
  for _, id in ipairs(values or {}) do
    if type(id) ~= "string" or id == "" then
      fail(field .. " entries must be non-empty strings", 3)
    end
    result[id] = true
  end
  return result
end

local function restoreParty(snapshot)
  local party = PartyService.new()
  for _, member in ipairs(snapshot or {}) do
    local result, reason = party:give(
      member.speciesId,
      member.level,
      member.heldItemId,
      member
    )
    if not result then fail("could not restore party: " .. reason, 3) end
  end
  return party
end

local function restoreInventory(snapshot)
  local inventory = InventoryService.new()
  for id, count in pairs(snapshot or {}) do inventory:give(id, count) end
  return inventory
end

local function restorePhone(snapshot)
  local phone = PhoneService.new()
  for _, id in ipairs(snapshot or {}) do phone:register(id) end
  return phone
end

local function normalizeLocation(source)
  if source == nil then return nil end
  if type(source) ~= "table"
      or type(source.mapId) ~= "string"
      or source.mapId == "" then
    fail("player location requires a mapId", 3)
  end
  requireInteger(source.x, 0, 65535, "player x")
  requireInteger(source.y, 0, 65535, "player y")
  local facing = source.facing or "down"
  if facing ~= "up" and facing ~= "down"
      and facing ~= "left" and facing ~= "right" then
    fail("player facing is invalid", 3)
  end
  return {
    mapId = source.mapId,
    x = source.x,
    y = source.y,
    facing = facing,
  }
end

function GameSession.new(profileId, options)
  options = options or {}
  if type(profileId) ~= "string" or profileId == "" then
    fail("profileId is required", 2)
  end
  local snapshot = options.snapshot
  if snapshot then
    if snapshot.schema ~= SCHEMA then
      fail("unsupported snapshot schema " .. tostring(snapshot.schema), 2)
    end
    if snapshot.profileId ~= profileId then
      fail("snapshot belongs to a different ROM profile", 2)
    end
  end
  local state = options.state
    or ScriptState.new(snapshot and snapshot.script or nil)
  local clock = copy(snapshot and snapshot.clock or options.clock or {})
  clock.hour = clock.hour
    or state:getVariable("clock.hour", 10)
  clock.minute = clock.minute
    or state:getVariable("clock.minute", 0)
  requireInteger(clock.hour, 0, 23, "clock hour")
  requireInteger(clock.minute, 0, 59, "clock minute")
  if clock.weekday ~= nil then
    requireInteger(clock.weekday, 0, 6, "clock weekday")
  end

  local self = setmetatable({
    schema = SCHEMA,
    profileId = profileId,
    state = state,
    party = options.party
      or restoreParty(snapshot and snapshot.party),
    inventory = options.inventory
      or restoreInventory(snapshot and snapshot.inventory),
    phone = options.phone
      or restorePhone(snapshot and snapshot.phone),
    storage = options.storage
      or StorageService.new(snapshot and snapshot.storage),
    clock = clock,
    money = snapshot and snapshot.money or options.money or 0,
    player = normalizeLocation(
      snapshot and snapshot.player or options.player),
    pokedex = {
      seen = setFromArray(
        snapshot and snapshot.pokedex and snapshot.pokedex.seen,
        "Pokédex seen"
      ),
      caught = setFromArray(
        snapshot and snapshot.pokedex and snapshot.pokedex.caught,
        "Pokédex caught"
      ),
    },
  }, GameSession)
  requireInteger(self.money, 0, 999999, "money")
  return self
end

function GameSession:setClock(hour, minute, weekday)
  self.clock.hour = requireInteger(hour, 0, 23, "clock hour")
  self.clock.minute = requireInteger(minute, 0, 59, "clock minute")
  if weekday ~= nil then
    self.clock.weekday =
      requireInteger(weekday, 0, 6, "clock weekday")
  end
end

function GameSession:captureWorld(world)
  self.player = normalizeLocation({
    mapId = world.currentMapId,
    x = world.player.x,
    y = world.player.y,
    facing = world.player.facing,
  })
  return self.player
end

function GameSession:markSeen(speciesId)
  if type(speciesId) ~= "string" or speciesId == "" then
    fail("seen species ID is required", 2)
  end
  self.pokedex.seen[speciesId] = true
end

function GameSession:markCaught(speciesId)
  self:markSeen(speciesId)
  self.pokedex.caught[speciesId] = true
end

function GameSession:snapshot()
  return {
    schema = SCHEMA,
    profileId = self.profileId,
    script = self.state:snapshot(),
    party = copyArray(self.party.members),
    inventory = copy(self.inventory.items),
    phone = copyArray(self.phone.order),
    storage = self.storage:snapshot(),
    clock = copy(self.clock),
    money = self.money,
    player = self.player and copy(self.player) or nil,
    pokedex = {
      seen = sortedSet(self.pokedex.seen),
      caught = sortedSet(self.pokedex.caught),
    },
  }
end

GameSession.SCHEMA = SCHEMA

return GameSession
