local Charmap = require("src.import.Charmap")
local CrystalSpecies = require("src.import.CrystalSpecies")

local CrystalBattleData = {}

local TYPES = {
  [0] = "normal",
  [1] = "fighting",
  [2] = "flying",
  [3] = "poison",
  [4] = "ground",
  [5] = "rock",
  [6] = "bird",
  [7] = "bug",
  [8] = "ghost",
  [9] = "steel",
  [19] = "curse",
  [20] = "fire",
  [21] = "water",
  [22] = "grass",
  [23] = "electric",
  [24] = "psychic",
  [25] = "ice",
  [26] = "dragon",
  [27] = "dark",
}

local EFFECTS = {
  [1] = "battle.effect.inflict_sleep",
  [2] = "battle.effect.inflict_poison",
  [3] = "battle.effect.drain",
  [4] = "battle.effect.inflict_burn",
  [5] = "battle.effect.inflict_freeze",
  [6] = "battle.effect.inflict_paralysis",
  [10] = "battle.effect.raise_attack",
  [11] = "battle.effect.raise_defense",
  [12] = "battle.effect.raise_speed",
  [13] = "battle.effect.raise_specialAttack",
  [14] = "battle.effect.raise_specialDefense",
  [15] = "battle.effect.raise_accuracy",
  [16] = "battle.effect.raise_evasion",
  [18] = "battle.effect.lower_attack",
  [19] = "battle.effect.lower_defense",
  [20] = "battle.effect.lower_speed",
  [21] = "battle.effect.lower_specialAttack",
  [22] = "battle.effect.lower_specialDefense",
  [23] = "battle.effect.lower_accuracy",
  [24] = "battle.effect.lower_evasion",
  [31] = "battle.effect.flinch",
  [33] = "battle.effect.inflict_toxic",
  [48] = "battle.effect.recoil",
  [66] = "battle.effect.inflict_poison",
  [67] = "battle.effect.inflict_paralysis",
  [68] = "battle.effect.lower_attack",
  [69] = "battle.effect.lower_defense",
  [70] = "battle.effect.lower_speed",
  [71] = "battle.effect.lower_specialAttack",
  [72] = "battle.effect.lower_specialDefense",
  [73] = "battle.effect.lower_accuracy",
  [74] = "battle.effect.lower_evasion",
}

local HIGH_CRITICAL_MOVES = {
  [2] = true,
  [13] = true,
  [75] = true,
  [152] = true,
  [163] = true,
  [177] = true,
  [238] = true,
}

local function semanticId(kind, number, name)
  local slug = name:lower():gsub("[^a-z0-9]+", "_")
    :gsub("^_+", ""):gsub("_+$", "")
  if slug == "" then slug = "unnamed" end
  return ("crystal.%s.%03d.%s"):format(kind, number, slug)
end

local function requireBattleProfile(profile)
  local battle = profile and profile.battle
  if type(battle) ~= "table"
      or type(battle.moves) ~= "table"
      or type(battle.moveNames) ~= "table" then
    error("battle data profile is missing ROM boundaries", 3)
  end
  return battle
end

local function readName(rom, offset, metadata)
  local bytes = {}
  for index = 0, metadata.maximumLength - 1 do
    local value = rom:readByte(offset + index)
    bytes[#bytes + 1] = string.char(value)
    if value == metadata.terminator then
      return Charmap.decodePlain(table.concat(bytes)), offset + index + 1
    end
  end
  error("battle data: move name exceeds maximum length", 3)
end

function CrystalBattleData.normalizeSpecies(source, index)
  local firstType = TYPES[source.types[1]]
  local secondType = TYPES[source.types[2]]
  if not firstType or not secondType then
    error(("battle data: species %d has an unknown type"):format(index), 2)
  end
  local types = { firstType }
  if secondType ~= firstType then types[2] = secondType end
  return {
    id = semanticId("species", index, source.name),
    name = source.name,
    stats = source.stats,
    types = types,
    catchRate = source.catchRate,
    baseExperience = source.baseExperience,
    growthRate = source.growthRate,
    gender = { threshold = source.gender.threshold },
  }
end

function CrystalBattleData.decodeMove(record, index, name)
  if type(record) ~= "string" or #record ~= 7 then
    error("battle data: move record must contain seven bytes", 2)
  end
  local storedId = record:byte(1)
  if storedId ~= index then
    error(("battle data: move %d stores id %d")
      :format(index, storedId), 2)
  end
  local effect = record:byte(2)
  local typeId = record:byte(4)
  local moveType = TYPES[typeId]
  if not moveType then
    error(("battle data: move %d has unknown type %d")
      :format(index, typeId), 2)
  end
  return {
    id = semanticId("move", index, name),
    name = name,
    effectId = EFFECTS[effect] or "battle.effect.none",
    power = record:byte(3),
    type = moveType,
    accuracy = record:byte(5),
    pp = record:byte(6),
    effectChance = record:byte(7),
    priority = effect == 103 and 1 or 0,
    criticalLevel = HIGH_CRITICAL_MOVES[index] and 1 or 0,
    nativeEffect = effect,
  }
end

function CrystalBattleData.extract(rom, profile)
  local metadata = requireBattleProfile(profile)
  local speciesSource = CrystalSpecies.extract(rom, profile)
  local species = {}
  local speciesIds = {}
  for index, source in ipairs(speciesSource.records) do
    local record = CrystalBattleData.normalizeSpecies(source, index)
    species[index] = record
    speciesIds[index] = record.id
  end

  local moves = {}
  local moveIds = {}
  local moveOffset = rom:offset(
    metadata.moves.bank,
    metadata.moves.address,
    metadata.moves.count * metadata.moves.recordSize
  )
  local nameOffset = rom:offset(
    metadata.moveNames.bank,
    metadata.moveNames.address,
    1
  )
  for index = 1, metadata.moves.count do
    local name
    name, nameOffset = readName(rom, nameOffset, metadata.moveNames)
    local recordOffset =
      moveOffset + (index - 1) * metadata.moves.recordSize
    local record = CrystalBattleData.decodeMove(
      rom:readString(recordOffset, metadata.moves.recordSize),
      index,
      name
    )
    moves[index] = record
    moveIds[index] = record.id
  end

  return {
    schema = metadata.schema,
    species = species,
    moves = moves,
    items = {},
    trainers = {},
    speciesIds = speciesIds,
    moveIds = moveIds,
  }
end

CrystalBattleData.TYPES = TYPES

return CrystalBattleData
