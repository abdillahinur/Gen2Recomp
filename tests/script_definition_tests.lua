return function(test, equal, truthy, raises)
  local Provenance = require("data.scripts.Provenance")
  local ScriptDefinition = require("src.script.ScriptDefinition")

  local function definition()
    return {
      schema = 1,
      id = "crystal.maps.new_bark_town",
      game = "crystal",
      kind = "map",
      maps = { "24:4" },
      provenance = {
        Provenance.citation(
          "crystal",
          "maps/NewBarkTown.asm",
          { "NewBarkTown_MapScripts" },
          "Used to reproduce callback and interaction behavior."
        ),
      },
      coverage = {
        callbacks = { "crystal.new_bark.callback.flypoint" },
        scenes = {},
        coordEvents = {},
        bgEvents = {},
        objects = {},
      },
      behavior = {},
    }
  end

  test("ScriptDefinition accepts pinned behavioral provenance", function()
    local value = definition()
    equal(ScriptDefinition.validate(value), value)
    equal(value.provenance[1].source, "pret/pokecrystal")
    equal(#value.provenance[1].revision, 40)
  end)

  test("ScriptDefinition requires stable script and map IDs", function()
    local value = definition()
    value.id = "New Bark"
    raises(function() ScriptDefinition.validate(value) end,
      "dotted lowercase stable ID")

    value = definition()
    value.maps = { "NewBarkTown" }
    raises(function() ScriptDefinition.validate(value) end,
      "stable group:map")
  end)

  test("ScriptDefinition rejects unpinned or unsafe citations", function()
    local value = definition()
    value.provenance[1].revision = string.rep("0", 40)
    raises(function() ScriptDefinition.validate(value) end,
      "not pinned")

    value = definition()
    value.provenance[1].path = "../private/source.asm"
    raises(function() ScriptDefinition.validate(value) end,
      "safe repository%-relative")
  end)

  test("ScriptDefinition requires declared coverage and behavior", function()
    local value = definition()
    value.coverage.objects = {
      "crystal.new_bark.object.mom",
      "crystal.new_bark.object.mom",
    }
    raises(function() ScriptDefinition.validate(value) end, "duplicate ID")

    value = definition()
    value.behavior = nil
    raises(function() ScriptDefinition.validate(value) end,
      "behavior must be a table")
  end)

  test("ScriptDefinition allows source-original common systems", function()
    local value = definition()
    value.id = "common.events.shared"
    value.game = "common"
    value.kind = "shared"
    value.maps = {}
    value.provenance = nil
    truthy(ScriptDefinition.validate(value))
  end)
end
