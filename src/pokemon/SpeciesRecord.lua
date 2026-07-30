local Validation = require("src.pokemon.RecordValidation")

local SpeciesRecord = {}

local STAT_NAMES = {
  "hp",
  "attack",
  "defense",
  "speed",
  "specialAttack",
  "specialDefense",
}

function SpeciesRecord.normalize(source)
  local kind = "species"
  if type(source) ~= "table" then
    Validation.fail(kind, "source must be a table", 2)
  end
  local stats = {}
  for _, name in ipairs(STAT_NAMES) do
    stats[name] = Validation.integer(
      kind,
      source.stats and source.stats[name],
      1,
      255,
      "stats." .. name
    )
  end
  local types = Validation.array(kind, source.types, "types", 1)
  if #types > 2 then
    Validation.fail(kind, "types cannot contain more than two entries", 2)
  end
  for index, value in ipairs(types) do
    if type(value) ~= "string" and type(value) ~= "number" then
      Validation.fail(kind, "type IDs must be strings or numbers", 2)
    end
    types[index] = value
  end
  return {
    id = Validation.id(kind, source.id),
    name = Validation.id(kind, source.name, "name"),
    stats = stats,
    types = types,
    catchRate = Validation.integer(
      kind, source.catchRate, 1, 255, "catchRate"),
    baseExperience = Validation.integer(
      kind, source.baseExperience, 1, 255, "baseExperience"),
    growthRate = Validation.integer(
      kind, source.growthRate, 0, 5, "growthRate"),
    gender = {
      threshold = Validation.integer(
        kind,
        source.gender and source.gender.threshold,
        0,
        255,
        "gender.threshold"
      ),
    },
  }
end

return SpeciesRecord
