local Json = require("src.core.Json")

local CrystalEncounterData = {}

local GRASS_RECORD_SIZE = 47
local WATER_RECORD_SIZE = 9
local GRASS_SLOT_COUNT = 7
local WATER_SLOT_COUNT = 3
local PERIODS = { "morning", "day", "night" }
local GRASS_WEIGHTS = { 30, 30, 20, 10, 5, 4, 1 }
local WATER_WEIGHTS = { 60, 30, 10 }

local function requireSymbol(profile, name)
  local symbol = profile.symbols and profile.symbols[name]
  if type(symbol) ~= "table" or type(symbol.offset) ~= "number" then
    error("encounter profile is missing symbol " .. name, 3)
  end
  return symbol
end

local function mapId(group, map)
  return ("%d:%d"):format(group, map)
end

local function requireSlot(level, species, label)
  if level < 1 or level > 100 then
    error(("%s has invalid level %d"):format(label, level), 3)
  end
  if species < 1 or species > 251 then
    error(("%s has invalid species %d"):format(label, species), 3)
  end
end

local function slot(rom, offset, weight, label)
  local level = rom:readByte(offset)
  local species = rom:readByte(offset + 1)
  requireSlot(level, species, label)
  return {
    level = level,
    speciesNumber = species,
    weight = weight,
  }
end

local function readGrass(rom, profile, allowed, records)
  local start = requireSymbol(profile, "JohtoGrassWildMons")
  local cursor = start.offset
  local scanned = 0
  while rom:readByte(cursor) ~= 0xff do
    rom:assertRange(cursor, GRASS_RECORD_SIZE)
    local group = rom:readByte(cursor)
    local map = rom:readByte(cursor + 1)
    local id = mapId(group, map)
    local record = records[id] or {
      mapId = id,
      group = group,
      map = map,
    }
    local periods = {}
    for periodIndex, period in ipairs(PERIODS) do
      local slots = Json.array({})
      local slotStart = cursor + 5
        + (periodIndex - 1) * GRASS_SLOT_COUNT * 2
      for index = 1, GRASS_SLOT_COUNT do
        slots[index] = slot(
          rom,
          slotStart + (index - 1) * 2,
          GRASS_WEIGHTS[index],
          id .. " grass " .. period
        )
      end
      periods[period] = slots
    end
    if allowed[id] then
      record.grass = {
        rates = {
          morning = rom:readByte(cursor + 2),
          day = rom:readByte(cursor + 3),
          night = rom:readByte(cursor + 4),
        },
        periods = periods,
      }
      records[id] = record
    end
    scanned = scanned + 1
    if scanned > 256 then
      error("grass encounter table is not terminated", 3)
    end
    cursor = cursor + GRASS_RECORD_SIZE
  end
  return scanned
end

local function readWater(rom, profile, allowed, records)
  local start = requireSymbol(profile, "JohtoWaterWildMons")
  local cursor = start.offset
  local scanned = 0
  while rom:readByte(cursor) ~= 0xff do
    rom:assertRange(cursor, WATER_RECORD_SIZE)
    local group = rom:readByte(cursor)
    local map = rom:readByte(cursor + 1)
    local id = mapId(group, map)
    local record = records[id] or {
      mapId = id,
      group = group,
      map = map,
    }
    local slots = Json.array({})
    for index = 1, WATER_SLOT_COUNT do
      slots[index] = slot(
        rom,
        cursor + 3 + (index - 1) * 2,
        WATER_WEIGHTS[index],
        id .. " water"
      )
    end
    if allowed[id] then
      record.water = {
        rate = rom:readByte(cursor + 2),
        slots = slots,
      }
      records[id] = record
    end
    scanned = scanned + 1
    if scanned > 256 then
      error("water encounter table is not terminated", 3)
    end
    cursor = cursor + WATER_RECORD_SIZE
  end
  return scanned
end

function CrystalEncounterData.extract(rom, profile, allowedMaps)
  if type(allowedMaps) ~= "table" then
    error("encounter extraction requires an allowed-map set", 2)
  end
  local records = {}
  local grassSourceCount =
    readGrass(rom, profile, allowedMaps, records)
  local waterSourceCount =
    readWater(rom, profile, allowedMaps, records)
  local maps = Json.array({})
  for _, record in pairs(records) do maps[#maps + 1] = record end
  table.sort(maps, function(left, right)
    if left.group == right.group then return left.map < right.map end
    return left.group < right.group
  end)
  return {
    schema = 1,
    maps = maps,
    sourceCounts = {
      grass = grassSourceCount,
      water = waterSourceCount,
    },
  }
end

CrystalEncounterData.GRASS_RECORD_SIZE = GRASS_RECORD_SIZE
CrystalEncounterData.WATER_RECORD_SIZE = WATER_RECORD_SIZE

return CrystalEncounterData
