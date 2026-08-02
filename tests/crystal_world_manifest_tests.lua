return function(test, equal, truthy)
  local manifest = require("manifests.crystal_world")
  local CrystalWorldData = require("src.import.CrystalWorldData")

  test("Crystal world extraction supports the upstairs player tileset", function()
    equal(CrystalWorldData.tilesetName(20), "players_room")
  end)

  test("Crystal world manifest defines the first-badge route", function()
    local expected = {
      [24] = { name = "new_bark", headers = 13, extracted = 13 },
      [26] = { name = "cherrygrove", headers = 11, extracted = 11 },
      [10] = { name = "violet", headers = 17, extracted = 17 },
    }
    local seen = {}
    for _, group in ipairs(manifest.groups) do
      local spec = expected[group.id]
      truthy(spec, "unexpected map group " .. tostring(group.id))
      equal(group.name, spec.name)
      equal(#group.maps, spec.headers)
      equal(#group.extractMapIndexes, spec.extracted)
      for _, index in ipairs(group.extractMapIndexes) do
        truthy(group.maps[index],
          group.name .. " extraction index is invalid")
      end
      seen[group.id] = true
    end
    equal(#manifest.groups, 3)
    truthy(seen[24] and seen[26] and seen[10])
    equal(manifest.initialMap.group, 24)
    equal(manifest.initialMap.map, 4)
  end)

  test("Crystal world manifest keeps named traversal closure indexes", function()
    local groups = {}
    for _, group in ipairs(manifest.groups) do groups[group.id] = group end
    equal(groups[24].maps[6], "players_house_1f")
    equal(groups[24].maps[7], "players_house_2f")
    equal(groups[10].maps[12], "route_32_ruins_of_alph_gate")
    equal(groups[10].maps[13], "route_32_pokecenter_1f")

    local function extracted(group, index)
      for _, value in ipairs(group.extractMapIndexes) do
        if value == index then return true end
      end
      return false
    end
    truthy(extracted(groups[24], 6))
    truthy(extracted(groups[24], 7))
    truthy(extracted(groups[10], 12))
    truthy(extracted(groups[10], 13))
  end)
end
