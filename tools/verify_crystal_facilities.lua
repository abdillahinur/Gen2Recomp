local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalWorldData = require("src.import.CrystalWorldData")
local FacilityPresentation =
  require("src.ui.FacilityPresentation")
local FacilityService = require("src.game.FacilityService")
local GameSession = require("src.game.GameSession")
local MapRepository = require("src.world.MapRepository")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then error("could not open ROM: " .. tostring(message), 2) end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-010 verification failed: " .. message, 2)
  end
end

local function input(action)
  return {
    wasPressed = function(_, candidate)
      return action == candidate
    end,
  }
end

local function stableId(species)
  return "crystal.species." .. species.id:match("([^.]+)$")
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then return 2 end
  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(data)
  data = nil
  local world = CrystalWorldData.extract(rom, identity.profile)
  local battle = CrystalBattleData.extract(rom, identity.profile)
  rom = nil
  local maps = MapRepository.new(world)

  for _, expected in ipairs({
    { id = "26:4", sprite = 57 },
    { id = "26:5", sprite = 55 },
    { id = "10:6", sprite = 57 },
    { id = "10:10", sprite = 55 },
  }) do
    local map = maps:getMap(expected.id)
    requireValue(map and map.objects[1],
      "facility map or first service object is missing: " .. expected.id)
    requireValue(map.objects[1].spriteId == expected.sprite,
      "facility service object changed: " .. expected.id)
  end

  local game = GameSession.new(identity.profile.id, { money = 2000 })
  game.party:give(stableId(battle.species[155]), 5, nil, {
    currentHP = 1,
  })
  game.party:give(stableId(battle.species[16]), 3, nil, {
    currentHP = 1,
  })
  local service = FacilityService.new(game, battle)
  service:healParty()
  requireValue(game.party.members[1].currentHP > 1,
    "Center did not heal the ROM-backed starter")

  local mart = FacilityPresentation.new(
    "mart", service, { catalogId = "cherrygrove" })
  mart:update(input("confirm"))
  mart:update(input("confirm"))
  requireValue(game.inventory:count("crystal.item.potion") == 1
      and game.money == 1700,
    "visible mart purchase did not update the session")

  local center = FacilityPresentation.new("center", service)
  center:update(input("down"))
  center:update(input("confirm"))
  center:update(input("confirm"))
  center:update(input("down"))
  center:update(input("confirm"))
  requireValue(#game.party.members == 1
      and #game.storage.pokemon == 1,
    "visible PC deposit did not preserve the stored Pokemon")
  local snapshot = game:snapshot()
  local restored = GameSession.new(identity.profile.id, {
    snapshot = snapshot,
  })
  requireValue(#restored.storage.pokemon == 1,
    "PC storage did not round-trip through the session snapshot")

  io.write(("M5-010 verified %s: Centers, marts, and PC storage\n")
    :format(identity.profile.id))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result), "\n")
  os.exit(1)
end
os.exit(result)
