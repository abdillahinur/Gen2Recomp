local BattleBridge = require("src.battle.BattleBridge")
local BattleRequestFactory =
  require("src.battle.BattleRequestFactory")
local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalWorldData = require("src.import.CrystalWorldData")
local DataRegistry = require("src.pokemon.DataRegistry")
local EncounterController = require("src.world.EncounterController")
local GameSession = require("src.game.GameSession")
local MapGrid = require("src.world.MapGrid")
local MapRepository = require("src.world.MapRepository")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local StateStack = require("src.core.StateStack")

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
    error("M5-006 verification failed: " .. message, 2)
  end
end

local function findMap(worldData, id)
  for _, group in ipairs(worldData.groups) do
    for _, map in ipairs(group.maps) do
      if map.id == id then return map end
    end
  end
end

local function findEncounter(worldData, id)
  for _, record in ipairs(worldData.encounters.maps) do
    if record.mapId == id then return record end
  end
end

local function sequenceRng(values)
  return {
    index = 0,
    nextByte = function(self)
      self.index = self.index + 1
      return values[self.index] or 0
    end,
  }
end

local function grassCell(worldData, map)
  local repository = MapRepository.new(worldData)
  local grid = MapGrid.new(map, repository:getTileset(map.tilesetId))
  for y = 0, grid.heightCells - 1 do
    for x = 0, grid.widthCells - 1 do
      local collision = grid:collisionAt(x, y)
      if collision == 0x18 then return x, y, grid end
    end
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_encounters.lua <path-to-ROM>\n"
    )
    return 2
  end

  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(data)
  data = nil
  local worldData = CrystalWorldData.extract(rom, identity.profile)
  local battleData = CrystalBattleData.extract(rom, identity.profile)
  rom = nil

  requireValue(#worldData.encounters.maps == 8,
    "first-badge slice must expose eight encounter maps")
  requireValue(worldData.encounters.sourceCounts.grass == 61,
    "Johto grass source count changed")
  requireValue(worldData.encounters.sourceCounts.water == 38,
    "Johto water source count changed")
  local route29 = findEncounter(worldData, "24:3")
  requireValue(route29 and route29.grass,
    "Route 29 grass encounters are unavailable")
  requireValue(route29.grass.periods.morning[1].speciesNumber == 16,
    "Route 29 morning lead must be species 16")
  requireValue(route29.grass.periods.night[1].speciesNumber == 163,
    "Route 29 night lead must be species 163")
  requireValue(route29.grass.periods.morning[1].level == 2,
    "Route 29 lead level must be 2")

  local map = findMap(worldData, "24:3")
  local x, y, grid = grassCell(worldData, map)
  requireValue(x ~= nil, "Route 29 has no encounter grass cell")

  local registry = DataRegistry.new(battleData)
  local game = GameSession.new(identity.profile.id)
  game.party:give(battleData.speciesIds[152], 5)
  local states = StateStack.new()
  states:push({ pause = function() end })
  local bridge = BattleBridge.new(
    states,
    BattleRequestFactory.new(registry, battleData, game)
  )
  local controller = EncounterController.new(
    worldData.encounters,
    bridge,
    { period = function() return "night" end },
    { rng = sequenceRng({ 0, 0, 19 }) }
  )
  local world = {
    stepCount = 0,
    currentMapId = "24:3",
    player = { x = x, y = y },
    grid = grid,
  }
  for step = 1, 5 do
    world.stepCount = step
    requireValue(controller:afterStep(world, true) == nil,
      "map-entry cooldown ended too early")
  end
  world.stepCount = 6
  local request = controller:afterStep(world, true)
  requireValue(request ~= nil, "forced Route 29 encounter did not start")
  requireValue(request.options.encounter.period == "night",
    "session clock period was not used")
  requireValue(request.options.speciesNumber == 163,
    "night encounter did not select the nocturnal lead")
  requireValue(bridge.active ~= nil,
    "encounter request did not enter the battle bridge")
  local opponent = bridge.active.session.state.opponent:active()
  requireValue(opponent.speciesId == battleData.speciesIds[163],
    "battle factory did not resolve encounter species")
  requireValue(opponent.level == 2,
    "battle factory did not preserve encounter level")

  print("Crystal M5-006 encounter verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Encounter maps: 8 (grass source 61, water source 38)")
  print("Route 29 periods: morning species 16, night species 163")
  print(("Grass dispatch: 24:3 (%d,%d) -> species 163 level 2")
    :format(x, y))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
