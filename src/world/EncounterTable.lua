local EncounterTable = {}
EncounterTable.__index = EncounterTable

local GRASS_COLLISIONS = {
  [0x08] = true,
  [0x14] = true,
  [0x18] = true,
  [0x28] = true,
  [0x48] = true,
  [0x49] = true,
  [0x4a] = true,
  [0x4b] = true,
  [0x4c] = true,
}
local WATER_COLLISION = 0x29

local function speciesId(number)
  return ("crystal.species.%03d"):format(number)
end

local function randomPercent(rng)
  for _ = 1, 256 do
    local value = rng:nextByte()
    if value < 100 then return value + 1 end
  end
  error("encounter RNG did not produce a percentage", 3)
end

local function choose(slots, rng)
  local value = randomPercent(rng)
  local total = 0
  for _, entry in ipairs(slots) do
    total = total + entry.weight
    if value <= total then return entry end
  end
  error("encounter slot weights do not total 100", 3)
end

local function waterLevel(level, rng)
  local value = rng:nextByte()
  if value < math.floor(35 * 255 / 100) then return level end
  if value < math.floor(65 * 255 / 100) then return level + 1 end
  if value < math.floor(85 * 255 / 100) then return level + 2 end
  if value < math.floor(95 * 255 / 100) then return level + 3 end
  return level + 4
end

function EncounterTable.new(data)
  if type(data) ~= "table" or type(data.maps) ~= "table" then
    error("encounter table requires normalized map records", 2)
  end
  local maps = {}
  for _, record in ipairs(data.maps) do
    if maps[record.mapId] then
      error("encounter table has duplicate map " .. record.mapId, 2)
    end
    maps[record.mapId] = record
  end
  return setmetatable({ data = data, maps = maps }, EncounterTable)
end

function EncounterTable.terrainForCollision(collisionId)
  if collisionId == WATER_COLLISION then return "water" end
  if GRASS_COLLISIONS[collisionId] then return "grass" end
end

function EncounterTable:roll(mapId, period, terrain, rng)
  if period ~= "morning" and period ~= "day"
      and period ~= "night" then
    error("encounter period must be morning, day, or night", 2)
  end
  if terrain ~= "grass" and terrain ~= "water" then
    error("encounter terrain must be grass or water", 2)
  end
  if type(rng) ~= "table" or type(rng.nextByte) ~= "function" then
    error("encounter selection requires a byte RNG", 2)
  end
  local record = self.maps[mapId]
  local source = record and record[terrain]
  if not source then return nil end
  local rate = terrain == "grass"
    and source.rates[period] or source.rate
  if rng:nextByte() >= rate then return nil end
  local slots = terrain == "grass"
    and source.periods[period] or source.slots
  local selected = choose(slots, rng)
  local level = terrain == "water"
    and waterLevel(selected.level, rng) or selected.level
  return {
    kind = "wild",
    opponentId = speciesId(selected.speciesNumber),
    options = {
      speciesNumber = selected.speciesNumber,
      level = level,
      seed = rng:nextByte(),
      encounter = {
        mapId = mapId,
        period = period,
        terrain = terrain,
      },
    },
  }
end

return EncounterTable
