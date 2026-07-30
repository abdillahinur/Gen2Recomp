local Validation = require("src.pokemon.RecordValidation")

local TrainerRecord = {}

function TrainerRecord.normalize(source)
  local kind = "trainer"
  if type(source) ~= "table" then
    Validation.fail(kind, "source must be a table", 2)
  end
  local party = Validation.array(kind, source.party, "party", 1)
  if #party > 6 then
    Validation.fail(kind, "party cannot contain more than six members", 2)
  end
  local normalizedParty = {}
  for index, member in ipairs(party) do
    if type(member) ~= "table" then
      Validation.fail(kind, "party members must be tables", 2)
    end
    local moves = Validation.array(
      kind, member.moves or {}, "party moves", 0)
    if #moves > 4 then
      Validation.fail(kind, "party moves cannot exceed four", 2)
    end
    for moveIndex, moveId in ipairs(moves) do
      moves[moveIndex] =
        Validation.id(kind, moveId, "party move id")
    end
    normalizedParty[index] = {
      speciesId =
        Validation.id(kind, member.speciesId, "party speciesId"),
      level = Validation.integer(
        kind, member.level, 1, 100, "party level"),
      moves = moves,
      heldItemId = member.heldItemId,
    }
  end
  return {
    id = Validation.id(kind, source.id),
    name = Validation.id(kind, source.name, "name"),
    classId = Validation.id(kind, source.classId, "classId"),
    aiProfileId = Validation.id(
      kind,
      source.aiProfileId or "battle.ai.basic",
      "aiProfileId"
    ),
    party = normalizedParty,
  }
end

return TrainerRecord
