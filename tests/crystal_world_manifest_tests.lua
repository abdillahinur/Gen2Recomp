return function(test, equal, truthy)
  local manifest = require("manifests.crystal_world")

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
end
