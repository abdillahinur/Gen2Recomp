return function(test, equal, truthy, raises)
  local CrystalEncounterData =
    require("src.import.CrystalEncounterData")
  local Rom = require("src.import.Rom")

  local function fixture(badSpecies)
    local grass = {
      string.char(24, 3, 25, 20, 15),
    }
    for period = 1, 3 do
      for index = 1, 7 do
        grass[#grass + 1] = string.char(
          period + index,
          badSpecies and period == 1 and index == 1
            and 0 or period * 10 + index
        )
      end
    end
    grass[#grass + 1] = string.char(0xff)
    local grassData = table.concat(grass)

    local waterOffset = #grassData
    local waterData = string.char(
      24, 4, 15,
      10, 60,
      15, 61,
      20, 62,
      0xff
    )
    return grassData .. waterData, {
      symbols = {
        JohtoGrassWildMons = { offset = 0 },
        JohtoWaterWildMons = { offset = waterOffset },
      },
    }
  end

  test("Crystal encounter data normalizes selected map records", function()
    local data, profile = fixture()
    local result = CrystalEncounterData.extract(
      Rom.new(data),
      profile,
      { ["24:3"] = true, ["24:4"] = true }
    )

    equal(result.schema, 1)
    equal(result.sourceCounts.grass, 1)
    equal(result.sourceCounts.water, 1)
    equal(#result.maps, 2)
    equal(result.maps[1].mapId, "24:3")
    equal(result.maps[1].grass.rates.morning, 25)
    equal(result.maps[1].grass.periods.night[7].speciesNumber, 37)
    equal(result.maps[1].grass.periods.day[2].weight, 30)
    equal(result.maps[2].water.slots[3].level, 20)
    equal(result.maps[2].water.slots[3].weight, 10)
  end)

  test("Crystal encounter data filters maps and validates species", function()
    local data, profile = fixture()
    local result = CrystalEncounterData.extract(
      Rom.new(data),
      profile,
      { ["24:4"] = true }
    )
    equal(#result.maps, 1)
    equal(result.maps[1].mapId, "24:4")
    truthy(result.maps[1].water)

    local badData, badProfile = fixture(true)
    raises(function()
      CrystalEncounterData.extract(
        Rom.new(badData),
        badProfile,
        { ["24:3"] = true }
      )
    end, "invalid species")
  end)
end
