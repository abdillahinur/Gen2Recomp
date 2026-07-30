return function(test, equal, truthy, raises)
  local CrystalTrainerData =
    require("src.import.CrystalTrainerData")
  local Rom = require("src.import.Rom")

  local function fixture(invalidType)
    local pointerBytes = {}
    for _ = 1, 67 do
      pointerBytes[#pointerBytes + 1] = string.char(0x86, 0x00)
    end
    local group = table.concat({
      string.char(0x80, 0x50, 0, 4, 19, 0xff),
      string.char(
        0x81, 0x50,
        invalidType and 9 or 1,
        5, 16, 33, 45, 0, 0,
        0xff
      ),
    })
    return table.concat(pointerBytes) .. group, {
      symbols = {
        TrainerGroups = {
          offset = 0,
          bank = 0,
          address = 0,
        },
      },
    }
  end

  test("Crystal trainer data decodes referenced ROM parties", function()
    local data, profile = fixture()
    local result = CrystalTrainerData.extract(
      Rom.new(data),
      profile,
      {
        { classId = 1, partyId = 2 },
        { classId = 1, partyId = 2 },
      }
    )
    equal(result.schema, 1)
    equal(#result.records, 1)
    local trainer = result.records[1]
    equal(trainer.id, "crystal.trainer.01.002")
    equal(trainer.name, "B")
    equal(trainer.trainerType, 1)
    equal(#trainer.party, 1)
    equal(trainer.party[1].speciesNumber, 16)
    equal(trainer.party[1].level, 5)
    equal(#trainer.party[1].moveNumbers, 2)
    equal(trainer.party[1].moveNumbers[2], 45)
    truthy(trainer.aiProfileId)
  end)

  test("Crystal trainer data rejects invalid party types", function()
    local data, profile = fixture(true)
    raises(function()
      CrystalTrainerData.extract(
        Rom.new(data),
        profile,
        { { classId = 1, partyId = 2 } }
      )
    end, "invalid type")
  end)
end
