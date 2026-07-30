local BattleRequestFactory =
  require("src.battle.BattleRequestFactory")
local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalWorldData = require("src.import.CrystalWorldData")
local DataRegistry = require("src.pokemon.DataRegistry")
local GameSession = require("src.game.GameSession")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local TrainerController = require("src.world.TrainerController")
local World = require("src.world.World")

local VECTORS = {
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
}

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
    error("M5-007 verification failed: " .. message, 2)
  end
end

local function findMap(worldData, id)
  for _, group in ipairs(worldData.groups) do
    for _, map in ipairs(group.maps) do
      if map.id == id then return map end
    end
  end
end

local function findTrainer(worldData, id)
  for _, trainer in ipairs(worldData.trainers.records) do
    if trainer.id == id then return trainer end
  end
end

local function findTrainerObject(map, id)
  for _, object in ipairs(map.objects) do
    if object.trainer and object.trainer.id == id then return object end
  end
end

local function sightTarget(world, object)
  local vector = VECTORS[object.facing]
  if not vector then return nil end
  for distance = object.sightRange, 2, -1 do
    local clear = true
    for step = 1, distance do
      local x = object.x + vector.x * step
      local y = object.y + vector.y * step
      local collision = world.grid:collisionAt(x, y)
      if collision == nil
          or not world.collision:allows(collision, object.facing)
          or (step < distance
            and world:isObjectAt(x, y, object)) then
        clear = false
        break
      end
    end
    if clear then
      return object.x + vector.x * distance,
        object.y + vector.y * distance,
        distance
    end
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_trainers.lua <path-to-ROM>\n"
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

  requireValue(#worldData.trainers.records == 28,
    "first-badge world must reference 28 unique trainer parties")
  local joeyId = "crystal.trainer.22.001"
  local joey = findTrainer(worldData, joeyId)
  requireValue(joey and joey.name == "JOEY",
    "Youngster Joey was not decoded from the supplied ROM")
  requireValue(#joey.party == 1
      and joey.party[1].speciesNumber == 19
      and joey.party[1].level == 4,
    "Youngster Joey's party must contain level 4 species 19")

  local route30 = findMap(worldData, "26:1")
  local sourceObject = route30 and findTrainerObject(route30, joeyId)
  requireValue(sourceObject ~= nil,
    "Route 30 does not expose Youngster Joey's trainer metadata")
  requireValue(sourceObject.trainer.defeatFlagId == 1449,
    "Youngster Joey's persistent defeat flag changed")

  local violetGym = findMap(worldData, "10:7")
  requireValue(
    violetGym
      and findTrainerObject(
        violetGym, "crystal.trainer.24.001")
      and findTrainerObject(
        violetGym, "crystal.trainer.24.002"),
    "Violet Gym trainer objects are incomplete"
  )

  local world = World.new(worldData)
  world:relocate("26:1", sourceObject.x, sourceObject.y,
    "down", "verification")
  local object = world:getObject("26:1", sourceObject.id)
  local targetX, targetY, sightDistance = sightTarget(world, object)
  requireValue(targetX ~= nil,
    "Youngster Joey has no clear multi-cell sight line")
  world.player.x = targetX
  world.player.y = targetY
  world.player.pixelX = targetX * 16
  world.player.pixelY = targetY * 16
  world.stepCount = 1

  local game = GameSession.new(identity.profile.id)
  game.party:give(battleData.speciesIds[152], 5)
  local request
  local resolve
  local bridge = {
    start = function(_, value, callback)
      request = value
      resolve = callback
    end,
  }
  local controller = TrainerController.new(
    world,
    bridge,
    game,
    { rng = { nextByte = function() return 11 end } }
  )
  requireValue(controller:afterStep(true),
    "real Route 30 trainer sight did not trigger")
  requireValue(object.emote == "shock",
    "trainer did not display the shock emote")

  for _ = 1, 32 do
    if request then break end
    controller:update(World.STEP_SECONDS)
  end
  requireValue(request and request.kind == "trainer"
      and request.opponentId == joeyId,
    "trainer approach did not dispatch Joey's battle request")
  local distance = math.abs(object.x - world.player.x)
    + math.abs(object.y - world.player.y)
  requireValue(distance == 1,
    "trainer did not stop adjacent to the player")

  local registry = DataRegistry.new(battleData)
  local factory = BattleRequestFactory.new(
    registry,
    battleData,
    game,
    { trainers = worldData.trainers }
  )
  local battle = factory:create(request)
  local opponent = battle.state.opponent:active()
  requireValue(opponent.speciesId == battleData.speciesIds[19],
    "trainer request did not resolve Joey's ROM-backed species")
  requireValue(opponent.level == 4,
    "trainer request did not preserve Joey's ROM-backed level")

  resolve({ outcome = "player_win", won = true })
  local flag = TrainerController.defeatedFlag(object.trainer)
  requireValue(game.state:hasFlag(flag),
    "trainer victory did not persist the defeat flag")
  world.stepCount = 2
  requireValue(not controller:afterStep(true),
    "defeated trainer triggered a second battle")

  print("Crystal M5-007 trainer verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Trainer parties: 28")
  print(("Route 30 sight: Joey range %d, approach %d cells")
    :format(sourceObject.sightRange, sightDistance - 1))
  print("Battle party: species 19 level 4")
  print("Defeat flag: " .. flag)
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
