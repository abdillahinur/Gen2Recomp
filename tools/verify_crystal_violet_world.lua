local CrystalWorldData = require("src.import.CrystalWorldData")
local MapGrid = require("src.world.MapGrid")
local Profiles = require("src.import.Profiles")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local World = require("src.world.World")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then
    error("could not open supplied ROM: " .. tostring(message), 2)
  end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-005 verification failed: " .. message, 2)
  end
end

local function findGroup(worldData, id)
  for _, group in ipairs(worldData.groups) do
    if group.id == id then return group end
  end
end

local function findMap(worldData, id)
  for _, group in ipairs(worldData.groups) do
    for _, map in ipairs(group.maps) do
      if map.id == id then return map end
    end
  end
end

local function findConnection(map, direction)
  for _, connection in ipairs(map.connections) do
    if connection.direction == direction then return connection end
  end
end

local function requireConnection(
    worldData,
    sourceId,
    direction,
    targetId)
  local source = findMap(worldData, sourceId)
  requireValue(source ~= nil, "missing route map " .. sourceId)
  local connection = findConnection(source, direction)
  requireValue(connection and connection.targetMapId == targetId,
    ("%s %s connection must lead to %s")
      :format(sourceId, direction, targetId))
end

local function verifyRoute(worldData)
  requireConnection(worldData, "24:4", "west", "24:3")
  requireConnection(worldData, "24:3", "west", "26:3")
  requireConnection(worldData, "26:3", "east", "24:3")
  requireConnection(worldData, "26:3", "north", "26:1")
  requireConnection(worldData, "26:1", "south", "26:3")
  requireConnection(worldData, "26:1", "north", "26:2")
  requireConnection(worldData, "26:2", "south", "26:1")
  requireConnection(worldData, "26:2", "west", "10:5")
  requireConnection(worldData, "10:5", "east", "26:2")
end

local function verifyCityWarps(worldData, sourceId, externalTargets)
  local source = findMap(worldData, sourceId)
  requireValue(source ~= nil, "missing city map " .. sourceId)
  for _, warp in ipairs(source.warps) do
    local target = findMap(worldData, warp.targetMapId)
    if not target then
      requireValue(externalTargets[warp.targetMapId],
        sourceId .. " warp target is not extracted: "
          .. warp.targetMapId)
    else
      local reciprocal = target.warps[warp.targetWarp]
      requireValue(reciprocal ~= nil,
        sourceId .. " target warp is unavailable: "
          .. warp.targetMapId)
      requireValue(reciprocal.targetMapId == sourceId,
        sourceId .. " target does not return: " .. warp.targetMapId)
    end
  end
end

local function verifyMapGraphics(world)
  local checked = 0
  for _, group in ipairs(world.repository.data.groups) do
    for _, map in ipairs(group.maps) do
      local tileset = world.repository:getTileset(map.tilesetId)
      requireValue(tileset ~= nil,
        map.name .. " has no extracted tileset")
      local roof = world.repository:getRoof(map.group)
      local grid = MapGrid.new(map, tileset)
      for _, tileId in ipairs(grid.tileIds) do
        local slot = tileset.tileSlots[tileId + 1]
        local roofTile = roof and tileId >= 10 and tileId < 19
        local ordinaryTile = slot
          and type(slot.graphicIndex) == "number"
          and tileset.graphics.tiles[slot.graphicIndex + 1]
        requireValue(roofTile or ordinaryTile,
          map.name .. " references missing tile " .. tileId)
        checked = checked + 1
      end
    end
  end
  return checked
end

local function verifySemanticSprites(worldData)
  local route36 = findMap(worldData, "10:3")
  requireValue(route36 ~= nil, "Route 36 is not extracted")
  local found = false
  for _, object in ipairs(route36.objects) do
    if object.spriteId == 0xf4 then
      requireValue(object.spriteKind == "variable",
        "Route 36 variable sprite was treated as ordinary graphics")
      found = true
    end
  end
  requireValue(found, "Route 36 variable sprite metadata is missing")
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_violet_world.lua <path-to-ROM>\n"
    )
    return 2
  end

  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  requireValue(Profiles.get(identity.profile.id) == identity.profile,
    "profile registry changed during verification")
  local worldData =
    CrystalWorldData.extract(Rom.new(data), identity.profile)
  data = nil

  requireValue(#worldData.groups == 3,
    "expected New Bark, Cherrygrove, and Violet groups")
  requireValue(#findGroup(worldData, 24).headers == 13,
    "New Bark group must expose 13 headers")
  requireValue(#findGroup(worldData, 26).headers == 11,
    "Cherrygrove group must expose 11 headers")
  requireValue(#findGroup(worldData, 10).headers == 17,
    "Violet group must expose 17 headers")
  requireValue(#findGroup(worldData, 24).maps == 9,
    "New Bark group must extract nine selected maps")
  requireValue(#findGroup(worldData, 26).maps == 11,
    "Cherrygrove group must extract all eleven maps")
  requireValue(#findGroup(worldData, 10).maps == 9,
    "Violet group must extract nine selected maps")
  requireValue(#worldData.tilesets == 10,
    "vertical slice must extract ten referenced tilesets")
  requireValue(#worldData.sprites == 32,
    "vertical slice must extract 32 ordinary sprites")

  verifyRoute(worldData)
  verifyCityWarps(worldData, "26:3", {})
  verifyCityWarps(worldData, "10:5", { ["3:1"] = true })
  verifySemanticSprites(worldData)

  local tileReferences = verifyMapGraphics(World.new(worldData))
  print("Crystal M5-005 Violet world verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Groups/maps/headers: 3/29/41")
  print("Tilesets/sprites: 10/32")
  print("Route: New Bark -> Cherrygrove -> Route 30/31 -> Violet")
  print("Intentional external boundary: Sprout Tower (3:1)")
  print("Tile references checked: " .. tileReferences)
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
