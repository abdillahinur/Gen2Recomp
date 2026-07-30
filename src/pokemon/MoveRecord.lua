local Validation = require("src.pokemon.RecordValidation")

local MoveRecord = {}

function MoveRecord.normalize(source)
  local kind = "move"
  if type(source) ~= "table" then
    Validation.fail(kind, "source must be a table", 2)
  end
  local moveType = source.type
  if type(moveType) ~= "string" and type(moveType) ~= "number" then
    Validation.fail(kind, "type must be a string or number", 2)
  end
  return {
    id = Validation.id(kind, source.id),
    name = Validation.id(kind, source.name, "name"),
    type = moveType,
    power = Validation.integer(kind, source.power, 0, 255, "power"),
    accuracy = Validation.integer(
      kind, source.accuracy, 0, 255, "accuracy"),
    pp = Validation.integer(kind, source.pp, 1, 63, "pp"),
    priority = Validation.optionalInteger(
      kind, source.priority, -7, 7, "priority", 0),
    effectId = Validation.id(
      kind, source.effectId or "battle.effect.none", "effectId"),
    effectChance = Validation.optionalInteger(
      kind, source.effectChance, 0, 255, "effectChance", 0),
  }
end

return MoveRecord
