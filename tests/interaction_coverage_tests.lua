return function(test, equal, truthy, raises)
  local CrystalEventBindings =
    require("src.script.CrystalEventBindings")
  local WorldState = require("src.states.WorldState")

  local function definition(id, mapId)
    return {
      id = id,
      kind = "map",
      maps = { mapId },
      behavior = { objects = { ["b.one"] = function() end } },
    }
  end

  local function catalog(entry)
    return {
      all = function() return { entry } end,
      get = function(_, id) return id == entry.id and entry or nil end,
    }
  end

  -- The loader only sees maps through the repository, so an imported map with
  -- no catalog definition is exactly the case that used to slip through.
  local function world(mapIds)
    local maps = {}
    for _, id in ipairs(mapIds) do
      maps[id] = { id = id, objects = { { id = 1 } }, bgEvents = {} }
    end
    return {
      repository = {
        maps = maps,
        getMap = function(_, id) return maps[id] end,
      },
    }
  end

  test("event bindings reject an imported map with no coverage", function()
    local entry = definition("test.maps.one", "1:1")
    raises(function()
      CrystalEventBindings.load(world({ "1:1", "1:2" }), catalog(entry), {
        schema = 1,
        maps = {
          ["1:1"] = {
            definition = "test.maps.one",
            objects = { "b.one" },
          },
        },
      })
    end, "1:2 is imported but neither bound nor declared unimplemented")
  end)

  test("event bindings accept a declared unimplemented map", function()
    local entry = definition("test.maps.one", "1:1")
    local bound, unimplemented = CrystalEventBindings.load(
      world({ "1:1", "1:2" }), catalog(entry), {
        schema = 1,
        maps = {
          ["1:1"] = {
            definition = "test.maps.one",
            objects = { "b.one" },
          },
        },
        unimplemented = { ["1:2"] = "dialogue not yet authored" },
      })
    truthy(bound["1:1"])
    equal(bound["1:2"], nil)
    equal(unimplemented["1:2"], "dialogue not yet authored")
  end)

  test("shipped bindings cover every imported Crystal map", function()
    local manifest = require("manifests.crystal_event_bindings")
    local worldManifest = require("manifests.crystal_world")
    local declared = 0
    for _, group in ipairs(worldManifest.groups) do
      for _, index in ipairs(group.extractMapIndexes) do
        local id = ("%d:%d"):format(group.id, index)
        truthy(
          manifest.maps[id] or manifest.unimplemented[id],
          id .. " has neither a binding nor an unimplemented declaration")
        declared = declared + 1
      end
    end
    truthy(declared > 0)
  end)

  test("shipped Elm Lab binding covers the ROM officer object", function()
    local function events(count)
      local values = {}
      for index = 1, count do values[index] = { id = index } end
      return values
    end
    local scene = world({ "24:5" })
    scene.repository.maps["24:5"] = {
      id = "24:5",
      objects = events(6),
      bgEvents = events(16),
      coordEvents = events(8),
    }
    local bound = CrystalEventBindings.load(
      scene,
      require("src.script.ScriptCatalog").load(),
      require("manifests.crystal_event_bindings")
    )
    equal(
      bound["24:5"].objects[6],
      "crystal.elms_lab.object.officer"
    )
  end)

  test("authored maps reject an object with no behavior", function()
    local entry = definition("test.maps.one", "1:1")
    local scene = world({ "1:1" })
    scene.repository.maps["1:1"].objects = { { id = 1 }, { id = 2 } }
    raises(function()
      CrystalEventBindings.load(scene, catalog(entry), {
        schema = 1,
        maps = {
          ["1:1"] = {
            definition = "test.maps.one",
            objects = { "b.one" },
          },
        },
      })
    end, "1:1 objects 2 has no behavior and is not declared non%-interactive")
  end)

  test("authored maps accept declared non-interactive objects", function()
    local entry = definition("test.maps.one", "1:1")
    local scene = world({ "1:1" })
    scene.repository.maps["1:1"].objects = { { id = 1 }, { id = 2 } }
    local bound = CrystalEventBindings.load(scene, catalog(entry), {
      schema = 1,
      maps = {
        ["1:1"] = {
          definition = "test.maps.one",
          objects = { "b.one" },
          nonInteractive = { objects = { [2] = "decorative" } },
        },
      },
    })
    truthy(bound["1:1"])
  end)

  test("facility staff match by sprite rather than event index", function()
    local facility = { kind = "center", staffSpriteId = 0x37 }
    local objects = {
      { id = 1, spriteId = 0x03, visible = true, x = 3, y = 4 },
      { id = 5, spriteId = 0x37, visible = true, x = 3, y = 4 },
    }
    local staff = WorldState.facilityStaffAt(objects, facility, 3, 4)
    truthy(staff, "nurse should be found at a non-first event index")
    equal(staff.id, 5)
  end)

  test("facility staff ignore other sprites on the counter tile", function()
    local facility = { kind = "mart", staffSpriteId = 0x39 }
    local objects = {
      { id = 1, spriteId = 0x37, visible = true, x = 1, y = 1 },
    }
    equal(WorldState.facilityStaffAt(objects, facility, 1, 1), nil)
  end)

  test("facility staff ignore hidden and distant objects", function()
    local facility = { kind = "center", staffSpriteId = 0x37 }
    equal(WorldState.facilityStaffAt({
      { id = 1, spriteId = 0x37, visible = false, x = 2, y = 2 },
    }, facility, 2, 2), nil)
    equal(WorldState.facilityStaffAt({
      { id = 1, spriteId = 0x37, visible = true, x = 9, y = 9 },
    }, facility, 2, 2), nil)
  end)

  test("facility staff require a declared sprite", function()
    equal(WorldState.facilityStaffAt({
      { id = 1, spriteId = 0x37, visible = true, x = 0, y = 0 },
    }, { kind = "center" }, 0, 0), nil)
    equal(WorldState.facilityStaffAt({}, nil, 0, 0), nil)
  end)
end
