local CrystalWorldData = require("src.import.CrystalWorldData")
local MapGrid = require("src.world.MapGrid")
local Profiles = require("src.import.Profiles")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local Sha1 = require("src.import.Sha1")
local World = require("src.world.World")
local WorldRaster = require("src.render.WorldRaster")

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
    error("M2 verification failed: " .. message, 2)
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

local function verifyMapGraphics(world)
  local checked = 0
  for _, group in ipairs(world.repository.data.groups) do
    for _, map in ipairs(group.maps) do
      local tileset = world.repository:getTileset(map.tilesetId)
      local roof = world.repository:getRoof(map.group)
      local grid = MapGrid.new(map, tileset)
      for _, tileId in ipairs(grid.tileIds) do
        local slot = tileset.tileSlots[tileId + 1]
        local roofTile = roof and tileId >= 10 and tileId < 19
        local ordinaryTile = slot
          and type(slot.graphicIndex) == "number"
          and tileset.graphics.tiles[slot.graphicIndex + 1]
        requireValue(
          roofTile or ordinaryTile,
          map.name .. " references missing tile " .. tileId
        )
        checked = checked + 1
      end
    end
  end
  return checked
end

local function verifyWarps(worldData)
  local newBark = findMap(worldData, "24:4")
  requireValue(newBark and #newBark.warps == 4,
    "New Bark must have four warps")
  for _, warp in ipairs(newBark.warps) do
    local target = findMap(worldData, warp.targetMapId)
    requireValue(target ~= nil,
      "warp target is not extracted: " .. warp.targetMapId)
    local reciprocal = target.warps[warp.targetWarp]
    requireValue(reciprocal ~= nil,
      "warp target id is unavailable")
    requireValue(reciprocal.targetMapId == "24:4",
      "building warp does not return to New Bark")
  end
end

local function placePlayer(world, x, y)
  world.player.x = x
  world.player.y = y
  world.player.pixelX = x * 16
  world.player.pixelY = y * 16
  world.player.moving = nil
end

local function verifyWarpTransitions(worldData)
  local newBark = findMap(worldData, "24:4")
  for _, warp in ipairs(newBark.warps) do
    local world = World.new(worldData)
    world:loadMap(newBark.id)
    placePlayer(world, warp.x, warp.y)
    world.warpCooldown = false
    world:checkWarp()
    requireValue(world.currentMapId == warp.targetMapId,
      "warp " .. warp.id .. " did not enter " .. warp.targetMapId)
    requireValue(world.lastTransition
        and world.lastTransition.kind == "warp"
        and world.lastTransition.resolved,
      "warp " .. warp.id .. " did not record a resolved transition")

    world.warpCooldown = false
    world:checkWarp()
    requireValue(world.currentMapId == newBark.id,
      "warp " .. warp.id .. " did not return to New Bark")
    requireValue(world.lastTransition
        and world.lastTransition.kind == "warp"
        and world.lastTransition.resolved,
      "return warp for " .. warp.id .. " was not resolved")
  end
end

local function verifyConnectionTransition(
  worldData,
  direction,
  targetMapId,
  traversableOnFoot
)
  local world = World.new(worldData)
  local x = direction == "left" and 0 or world.grid.widthCells - 1
  local transitionY
  for y = 0, world.grid.heightCells - 1 do
    placePlayer(world, x, y)
    if world:canMove(direction) then
      transitionY = y
      break
    end
  end
  if not traversableOnFoot then
    requireValue(transitionY == nil,
      direction .. " connection unexpectedly permits walking over water")
    local target = world:connectionDestination(direction, x, 0)
    requireValue(target and target.id == targetMapId,
      direction .. " connection did not resolve " .. targetMapId)
    placePlayer(world, x, 0)
    requireValue(not world:startMove(direction),
      direction .. " water boundary must block foot movement")
    return
  end
  requireValue(transitionY ~= nil,
    direction .. " connection has no walkable boundary cell")
  placePlayer(world, x, transitionY)
  requireValue(world:startMove(direction),
    direction .. " connection movement did not start")
  world:update(World.STEP_SECONDS, { down = function() return false end })
  requireValue(world.currentMapId == targetMapId,
    direction .. " connection did not enter " .. targetMapId)
  requireValue(world.lastTransition
      and world.lastTransition.kind == "connection"
      and world.lastTransition.direction == direction
      and world.lastTransition.resolved,
    direction .. " connection did not record a resolved transition")
end

local function verifyWorldTransitions(worldData)
  verifyWarpTransitions(worldData)
  verifyConnectionTransition(worldData, "left", "24:3", true)
  verifyConnectionTransition(worldData, "right", "24:2", false)
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_world.lua <path-to-ROM>\n"
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

  local newBarkGroup
  for _, group in ipairs(worldData.groups) do
    if group.id == 24 then newBarkGroup = group end
  end
  requireValue(newBarkGroup ~= nil, "New Bark group is not extracted")
  requireValue(#newBarkGroup.headers == 13,
    "New Bark group must expose 13 headers")
  requireValue(#newBarkGroup.maps >= 8,
    "New Bark slice must retain its original eight maps")
  requireValue(#worldData.tilesets >= 4,
    "New Bark slice must retain its original four tilesets")
  requireValue(#worldData.collisionPermissions == 256,
    "collision permission table must contain 256 records")
  requireValue(#worldData.sprites >= 16,
    "New Bark slice must retain its 16 referenced sprites")
  verifyWarps(worldData)
  verifyWorldTransitions(worldData)

  local newBark = findMap(worldData, "24:4")
  local west = findConnection(newBark, "west")
  local east = findConnection(newBark, "east")
  requireValue(west and west.targetMapId == "24:3",
    "west connection must lead to Route 29")
  requireValue(east and east.targetMapId == "24:2",
    "east connection must lead to Route 27")

  local world = World.new(worldData)
  world.camera:follow(
    world.player.pixelX + 8,
    world.player.pixelY + 8,
    world.grid.widthTiles * 8,
    world.grid.heightTiles * 8
  )
  local tileReferences = verifyMapGraphics(world)
  local hashes = {}
  for _, period in ipairs({ "morning", "day", "night" }) do
    local frame = WorldRaster.render(world, period)
    requireValue(#frame.pixels == 160 * 144 * 3,
      "software raster has an invalid byte count")
    hashes[#hashes + 1] = period .. "=" .. Sha1.hex(frame.pixels)
  end
  requireValue(hashes[1] ~= hashes[2] and hashes[2] ~= hashes[3],
    "time-of-day frames must be visually distinct")

  print("Crystal M2 world verification passed.")
  print("Profile: " .. identity.profile.id)
  print(("New Bark maps/headers: %d/13"):format(#newBarkGroup.maps))
  print(("World tilesets/sprites: %d/%d")
    :format(#worldData.tilesets, #worldData.sprites))
  print("Warps/connections: 4/2")
  print("Connection paths: west=traversed east=terrain-blocked")
  print("Tile references checked: " .. tileReferences)
  print("Frame hashes: " .. table.concat(hashes, " "))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
