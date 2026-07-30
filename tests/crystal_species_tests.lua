return function(test, equal, truthy, raises)
  local CrystalSpecies = require("src.import.CrystalSpecies")
  local Rom = require("src.import.Rom")

  local function makeRecord(index)
    local bytes = {}
    for position = 1, 32 do
      bytes[position] = 0
    end
    bytes[1] = index
    for position = 2, 7 do
      bytes[position] = 10 + position
    end
    bytes[8] = 1
    bytes[9] = 2
    bytes[10] = 45
    bytes[11] = 64
    bytes[12] = 0
    bytes[13] = 1
    bytes[14] = 0x7f
    bytes[15] = 100
    bytes[16] = 20
    bytes[17] = 5
    bytes[18] = 0x56
    bytes[23] = 3
    bytes[24] = 0x17
    if index == 1 then
      bytes[25] = 0x01
      bytes[32] = 0x08
    end
    local parts = {}
    for position, value in ipairs(bytes) do
      parts[position] = string.char(value)
    end
    return table.concat(parts)
  end

  local function fixture()
    local records = {}
    local names = {}
    for index = 1, CrystalSpecies.COUNT do
      records[index] = makeRecord(index)
      names[index] = string.char(0x80 + (index - 1) % 26)
        .. string.rep(string.char(0x50), CrystalSpecies.NAME_SIZE - 1)
    end
    -- The real name table reserves five additional fixed-width slots.
    return table.concat(records)
      .. table.concat(names)
      .. string.rep("\0", 5 * CrystalSpecies.NAME_SIZE)
  end

  local function profile()
    local baseLength =
      CrystalSpecies.COUNT * CrystalSpecies.RECORD_SIZE
    local namesLength =
      (CrystalSpecies.COUNT + 5) * CrystalSpecies.NAME_SIZE
    return {
      symbols = {
        BaseData = { offset = 0 },
        PokemonNames = { offset = baseLength },
        BetaMonPicBanks = { offset = baseLength + namesLength },
      },
    }
  end

  local function replaceByte(data, offset, value)
    return data:sub(1, offset)
      .. string.char(value)
      .. data:sub(offset + 2)
  end

  test("CrystalSpecies extracts normalized fixed-width records", function()
    local result = CrystalSpecies.extract(Rom.new(fixture()), profile())
    equal(result.schema, 1)
    equal(result.count, 251)
    equal(#result.records, 251)

    local first = result.records[1]
    equal(first.id, 1)
    equal(first.name, "A")
    equal(first.stats.hp, 12)
    equal(first.stats.specialDefense, 17)
    equal(first.types[1], 1)
    equal(first.heldItems[2], 1)
    equal(first.gender.category, "female_50")
    equal(first.sprite.widthTiles, 5)
    equal(first.sprite.heightTiles, 6)
    equal(first.growthRate, 3)
    equal(first.eggGroups[1], 1)
    equal(first.eggGroups[2], 7)
    equal(first.machineCompatibility[1], 1)
    equal(first.machineCompatibility[2], 60)
    equal(result.records[251].id, 251)
  end)

  test("CrystalSpecies rejects record identity and enum corruption",
    function()
      local female25 = CrystalSpecies.extract(
        Rom.new(replaceByte(fixture(), 13, 0x3f)),
        profile()
      )
      equal(female25.records[1].gender.category, "female_25")

      raises(function()
        CrystalSpecies.extract(
          Rom.new(replaceByte(fixture(), 0, 2)),
          profile()
        )
      end, "stores id")

      raises(function()
        CrystalSpecies.extract(
          Rom.new(replaceByte(fixture(), 22, 9)),
          profile()
        )
      end, "growth rate")

      raises(function()
        CrystalSpecies.extract(
          Rom.new(replaceByte(fixture(), 13, 0x40)),
          profile()
        )
      end, "gender threshold")
    end)

  test("CrystalSpecies rejects range and compatibility corruption",
    function()
      local badProfile = profile()
      badProfile.symbols.PokemonNames.offset =
        badProfile.symbols.PokemonNames.offset - 1
      raises(function()
        CrystalSpecies.extract(Rom.new(fixture()), badProfile)
      end, "BaseData length")

      raises(function()
        CrystalSpecies.extract(
          Rom.new(replaceByte(fixture(), 31, 0x80)),
          profile()
        )
      end, "unused machine")
    end)
end
