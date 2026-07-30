local Json = require("src.core.Json")

local CoverageReport = {}

local function percent(value, total)
  if total == 0 then return 100 end
  return math.floor(value * 1000 / total + 0.5) / 10
end

local function allMaps(worldData)
  local maps = {}
  for _, group in ipairs(worldData.groups or {}) do
    for _, map in ipairs(group.maps or {}) do maps[#maps + 1] = map end
  end
  table.sort(maps, function(left, right)
    if left.group == right.group then return left.map < right.map end
    return left.group < right.group
  end)
  return maps
end

local function functionCount(values)
  local count = 0
  for _, value in pairs(values or {}) do
    if type(value) == "function" then count = count + 1 end
  end
  return count
end

function CoverageReport.generate(worldData, catalog)
  local details = Json.array({})
  local summary = {
    definitions = #catalog:all(),
    flowScripts = 0,
    mapScripts = 0,
    maps = { covered = 0, available = 0, percent = 0 },
    callbacks = { declared = 0, implemented = 0 },
    scenes = { declared = 0, implemented = 0, flowBeats = 0 },
    actors = { declared = 0, resolved = 0 },
    interactions = {
      coordEvents = { declared = 0, available = 0, percent = 0 },
      bgEvents = { declared = 0, available = 0, percent = 0 },
      objects = { declared = 0, available = 0, percent = 0 },
    },
  }

  for _, definition in ipairs(catalog:all()) do
    if definition.kind == "flow" then
      summary.flowScripts = summary.flowScripts + 1
      summary.scenes.flowBeats =
        summary.scenes.flowBeats + #definition.coverage.scenes
    elseif definition.kind == "map" then
      summary.mapScripts = summary.mapScripts + 1
      summary.callbacks.declared =
        summary.callbacks.declared + #definition.coverage.callbacks
      summary.callbacks.implemented =
        summary.callbacks.implemented
          + functionCount(definition.behavior.callbacks)
      summary.scenes.declared =
        summary.scenes.declared + #definition.coverage.scenes
      summary.scenes.implemented =
        summary.scenes.implemented
          + functionCount(definition.behavior.scenes)
    end
  end

  local maps = allMaps(worldData)
  summary.maps.available = #maps
  for _, map in ipairs(maps) do
    local definition = catalog:forMap(map.id)
    local declared = {
      coordEvents = definition and #definition.coverage.coordEvents or 0,
      bgEvents = definition and #definition.coverage.bgEvents or 0,
      objects = definition and #definition.coverage.objects or 0,
    }
    local available = {
      coordEvents = #(map.coordEvents or {}),
      bgEvents = #(map.bgEvents or {}),
      objects = #(map.objects or {}),
    }
    local complete = definition ~= nil
    local actorBindings = { declared = 0, resolved = 0 }
    for _, actor in ipairs(definition and definition.actors or {}) do
      if actor.mapId == map.id then
        actorBindings.declared = actorBindings.declared + 1
        if map.objects and map.objects[actor.objectId] then
          actorBindings.resolved = actorBindings.resolved + 1
        else
          complete = false
        end
      end
    end
    summary.actors.declared =
      summary.actors.declared + actorBindings.declared
    summary.actors.resolved =
      summary.actors.resolved + actorBindings.resolved
    for kind, count in pairs(available) do
      summary.interactions[kind].available =
        summary.interactions[kind].available + count
      summary.interactions[kind].declared =
        summary.interactions[kind].declared + declared[kind]
      if declared[kind] ~= count then complete = false end
    end
    if definition then summary.maps.covered = summary.maps.covered + 1 end
    details[#details + 1] = {
      id = map.id,
      name = map.name,
      scriptId = definition and definition.id or Json.null,
      status = not definition and "uncovered"
        or complete and "covered" or "partial",
      callbacks = definition and #definition.coverage.callbacks or 0,
      scenes = definition and #definition.coverage.scenes or 0,
      actorBindings = actorBindings,
      interactions = {
        coordEvents = {
          declared = declared.coordEvents,
          available = available.coordEvents,
        },
        bgEvents = {
          declared = declared.bgEvents,
          available = available.bgEvents,
        },
        objects = {
          declared = declared.objects,
          available = available.objects,
        },
      },
    }
  end

  summary.maps.percent =
    percent(summary.maps.covered, summary.maps.available)
  for _, kind in ipairs({ "coordEvents", "bgEvents", "objects" }) do
    local item = summary.interactions[kind]
    item.percent = percent(item.declared, item.available)
  end

  return {
    schema = 1,
    summary = summary,
    maps = details,
  }
end

return CoverageReport
