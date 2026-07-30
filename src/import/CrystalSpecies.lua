local Charmap = require("src.import.Charmap")
local Json = require("src.core.Json")

local CrystalSpecies = {}

local SPECIES_COUNT = 251
local RECORD_SIZE = 32
local NAME_SIZE = 10
local MACHINE_COUNT = 60

local GENDER_CATEGORIES = {
  [0x00] = "male_only",
  [0x1f] = "female_12_5",
  [0x3f] = "female_25",
  [0x7f] = "female_50",
  [0xbf] = "female_75",
  [0xfe] = "female_only",
  [0xff] = "genderless",
}

local function requireSymbol(profile, name)
  local symbol = profile.symbols and profile.symbols[name]
  if type(symbol) ~= "table" or type(symbol.offset) ~= "number" then
    error("species profile is missing symbol " .. name, 3)
  end
  return symbol
end

local function decodeMachines(record)
  local machines = Json.array({})
  for machine = 1, MACHINE_COUNT do
    local zeroBased = machine - 1
    local byte = record:byte(25 + math.floor(zeroBased / 8))
    local mask = 2 ^ (zeroBased % 8)
    if math.floor(byte / mask) % 2 == 1 then
      machines[#machines + 1] = machine
    end
  end

  local final = record:byte(32)
  if math.floor(final / 0x10) ~= 0 then
    error("unused machine compatibility bits are set", 3)
  end
  return machines
end

local function decodeRecord(record, index, name)
  local speciesId = record:byte(1)
  if speciesId ~= index then
    error(("species record %d stores id %d"):format(index, speciesId), 3)
  end

  local stats = {
    hp = record:byte(2),
    attack = record:byte(3),
    defense = record:byte(4),
    speed = record:byte(5),
    specialAttack = record:byte(6),
    specialDefense = record:byte(7),
  }
  for statName, value in pairs(stats) do
    if value == 0 then
      error(("species %d has zero %s"):format(index, statName), 3)
    end
  end

  local genderThreshold = record:byte(14)
  local genderCategory = GENDER_CATEGORIES[genderThreshold]
  if not genderCategory then
    error(("species %d has unknown gender threshold 0x%02X")
      :format(index, genderThreshold), 3)
  end

  local growthRate = record:byte(23)
  if growthRate > 5 then
    error(("species %d has invalid growth rate %d")
      :format(index, growthRate), 3)
  end

  local eggGroups = record:byte(24)
  local eggGroup1 = math.floor(eggGroups / 0x10)
  local eggGroup2 = eggGroups % 0x10
  if eggGroup1 < 1 or eggGroup1 > 15
      or eggGroup2 < 1 or eggGroup2 > 15 then
    error(("species %d has invalid egg groups"):format(index), 3)
  end

  local dimensions = record:byte(18)
  local width = math.floor(dimensions / 0x10)
  local height = dimensions % 0x10
  if width == 0 or height == 0 then
    error(("species %d has invalid sprite dimensions"):format(index), 3)
  end

  return {
    id = speciesId,
    name = name,
    stats = stats,
    types = Json.array({ record:byte(8), record:byte(9) }),
    catchRate = record:byte(10),
    baseExperience = record:byte(11),
    heldItems = Json.array({ record:byte(12), record:byte(13) }),
    gender = {
      threshold = genderThreshold,
      category = genderCategory,
    },
    unknown1 = record:byte(15),
    hatchCycles = record:byte(16),
    unknown2 = record:byte(17),
    sprite = {
      widthTiles = width,
      heightTiles = height,
    },
    legacyPicturePointers = Json.array({
      record:byte(19) + record:byte(20) * 0x100,
      record:byte(21) + record:byte(22) * 0x100,
    }),
    growthRate = growthRate,
    eggGroups = Json.array({ eggGroup1, eggGroup2 }),
    machineCompatibility = decodeMachines(record),
  }
end

function CrystalSpecies.extract(rom, profile)
  local baseData = requireSymbol(profile, "BaseData")
  local pokemonNames = requireSymbol(profile, "PokemonNames")
  local namesEnd = requireSymbol(profile, "BetaMonPicBanks")

  local baseLength = pokemonNames.offset - baseData.offset
  local expectedBaseLength = SPECIES_COUNT * RECORD_SIZE
  if baseLength ~= expectedBaseLength then
    error(("Crystal BaseData length is %d; expected %d")
      :format(baseLength, expectedBaseLength), 2)
  end
  if namesEnd.offset - pokemonNames.offset < SPECIES_COUNT * NAME_SIZE then
    error("Crystal PokemonNames range is truncated", 2)
  end

  local records = Json.array({})
  for index = 1, SPECIES_COUNT do
    local recordOffset = baseData.offset + (index - 1) * RECORD_SIZE
    local nameOffset = pokemonNames.offset + (index - 1) * NAME_SIZE
    local record = rom:readString(recordOffset, RECORD_SIZE)
    local name = Charmap.decodePlain(rom:readString(nameOffset, NAME_SIZE))
    if name == "" then
      error(("species %d has an empty name"):format(index), 2)
    end
    records[index] = decodeRecord(record, index, name)
  end

  return {
    schema = 1,
    count = SPECIES_COUNT,
    records = records,
  }
end

CrystalSpecies.COUNT = SPECIES_COUNT
CrystalSpecies.RECORD_SIZE = RECORD_SIZE
CrystalSpecies.NAME_SIZE = NAME_SIZE

return CrystalSpecies
