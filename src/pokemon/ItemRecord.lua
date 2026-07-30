local Validation = require("src.pokemon.RecordValidation")

local ItemRecord = {}

function ItemRecord.normalize(source)
  local kind = "item"
  if type(source) ~= "table" then
    Validation.fail(kind, "source must be a table", 2)
  end
  local itemKind = Validation.id(kind, source.kind, "kind")
  return {
    id = Validation.id(kind, source.id),
    name = Validation.id(kind, source.name, "name"),
    kind = itemKind,
    price = Validation.integer(kind, source.price, 0, 65535, "price"),
    effectId = Validation.id(
      kind, source.effectId or "item.effect.none", "effectId"),
    catchRateModifier = Validation.optionalInteger(
      kind,
      source.catchRateModifier,
      1,
      255,
      "catchRateModifier",
      1
    ),
  }
end

return ItemRecord
