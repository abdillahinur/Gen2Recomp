local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local StaticMap = {}

local function behaviors(prefix, kind, values)
  local ids = {}
  local implementations = {}
  for index, value in ipairs(values or {}) do
    local id = ("%s.%s.event_%d"):format(prefix, kind, index)
    ids[index] = id
    implementations[id] = type(value) == "function"
      and value or Helpers.text(value)
  end
  return ids, implementations
end

function StaticMap.define(options)
  local bgIds, bgBehavior =
    behaviors(options.prefix, "bg", options.bgEvents)
  local objectIds, objectBehavior =
    behaviors(options.prefix, "object", options.objects)
  return {
    schema = 1,
    id = options.id,
    game = "crystal",
    kind = "map",
    maps = { options.mapId },
    provenance = {
      Provenance.citation(
        "crystal",
        options.path,
        options.labels,
        options.notes
      ),
    },
    coverage = {
      callbacks = {},
      scenes = {},
      coordEvents = {},
      bgEvents = bgIds,
      objects = objectIds,
    },
    behavior = {
      callbacks = {},
      scenes = {},
      coordEvents = {},
      bgEvents = bgBehavior,
      objects = objectBehavior,
    },
  }
end

return StaticMap
