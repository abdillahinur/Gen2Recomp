local CrystalEventBindings = {}

local KINDS = { "objects", "bgEvents", "coordEvents" }

local function fail(message, level)
  error("Crystal event bindings: " .. message, level or 3)
end

function CrystalEventBindings.load(world, catalog, manifest)
  manifest = manifest or require("manifests.crystal_event_bindings")
  if type(manifest) ~= "table" or manifest.schema ~= 1
      or type(manifest.maps) ~= "table" then
    fail("manifest must use schema 1", 2)
  end
  local result = {}
  for mapId, binding in pairs(manifest.maps) do
    local map = world.repository:getMap(mapId)
    if map then
      local definition = catalog:get(binding.definition)
      if not definition then
        fail(mapId .. " references missing definition "
          .. tostring(binding.definition), 2)
      end
      if not definition.maps or not definition.maps[1]
          or definition.maps[1] ~= mapId then
        fail(mapId .. " definition does not own the physical map", 2)
      end
      for _, kind in ipairs(KINDS) do
        local available = map[kind] or {}
        local declared = binding[kind] or {}
        if #declared > #available then
          fail(("%s binds %d %s but ROM map only has %d")
            :format(mapId, #declared, kind, #available), 2)
        end
        local behavior = definition.behavior[kind] or {}
        for eventId, behaviorId in ipairs(declared) do
          if type(behaviorId) ~= "string"
              or type(behavior[behaviorId]) ~= "function" then
            fail(("%s %s %d has no behavior %s")
              :format(mapId, kind, eventId, tostring(behaviorId)), 2)
          end
        end
      end
      result[mapId] = binding
    end
  end
  for _, definition in ipairs(catalog:all()) do
    if definition.kind == "map" then
      for _, mapId in ipairs(definition.maps) do
        if world.repository:getMap(mapId) and not result[mapId] then
          fail(mapId .. " has no explicit event binding", 2)
        end
      end
    end
  end
  return result
end

return CrystalEventBindings
