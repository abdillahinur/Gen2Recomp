local CrystalBattleData = require("src.import.CrystalBattleData")
local FieldMenuPresentation =
  require("src.ui.FieldMenuPresentation")
local GameSession = require("src.game.GameSession")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

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
    error("M5-009 verification failed: " .. message, 2)
  end
end

local function input(action)
  return {
    wasPressed = function(_, candidate)
      return action == candidate
    end,
  }
end

local function stableId(record)
  local slug = record.id:match("([^.]+)$")
  return "crystal.species." .. slug
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_field_menu.lua <path-to-ROM>\n"
    )
    return 2
  end

  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(data)
  data = nil
  local battleData =
    CrystalBattleData.extract(rom, identity.profile)
  rom = nil

  requireValue(#battleData.species == 251,
    "Pokédex must use all 251 ROM-derived species")
  local starter = battleData.species[155]
  local seenSpecies = battleData.species[16]
  requireValue(starter.name == "CYNDAQUIL",
    "starter species name was not decoded from the ROM")
  requireValue(seenSpecies.name == "PIDGEY",
    "seen species name was not decoded from the ROM")

  local game = GameSession.new(identity.profile.id)
  game.party:give(
    stableId(starter),
    5,
    "crystal.item.berry",
    {
      currentHP = 19,
      dvs = {
        attack = 10,
        defense = 10,
        speed = 10,
        special = 10,
      },
    }
  )
  game.inventory:give("crystal.item.potion", 2)
  game.inventory:give("crystal.item.mystery_egg", 1)
  game:markCaught(stableId(starter))
  game:markSeen(stableId(seenSpecies))

  local menu = FieldMenuPresentation.new(game, battleData)
  local root = menu:model()
  requireValue(root.options[1].disabled,
    "Pokédex opened before its story feature flag")
  menu:update(input("confirm"))
  requireValue(menu:model().kind == "root",
    "disabled Pokédex selection changed menu mode")

  menu:update(input("down"))
  menu:update(input("confirm"))
  local party = menu:model()
  requireValue(party.kind == "party" and #party.options == 1,
    "party presentation did not expose the persistent starter")
  requireValue(party.options[1].name == starter.name,
    "party did not resolve the ROM-derived species name")
  requireValue(party.options[1].level == 5
      and party.options[1].hp == 19
      and party.options[1].maxHP > 0,
    "party summary level or HP is invalid")

  menu:update(input("cancel"))
  menu:update(input("down"))
  menu:update(input("confirm"))
  local pack = menu:model()
  requireValue(pack.kind == "pack" and #pack.options == 2,
    "Pack did not expose persistent inventory entries")
  requireValue(pack.options[2].name == "POTION"
      and pack.options[2].quantity == 2,
    "Pack quantity presentation is invalid")

  menu:update(input("cancel"))
  menu:update(input("up"))
  menu:update(input("up"))
  game.state:setFlag("crystal.feature.pokedex")
  menu:update(input("confirm"))
  local pokedex = menu:model()
  requireValue(pokedex.kind == "pokedex"
      and #pokedex.options == 251,
    "Pokédex did not expose the complete species index")
  requireValue(pokedex.seen == 2 and pokedex.caught == 1,
    "Pokédex seen/caught totals are invalid")
  requireValue(pokedex.options[16].name == "PIDGEY",
    "seen species name is not visible")
  requireValue(pokedex.options[1].name == "----------",
    "unseen species name was revealed")

  io.write(("M5-009 verified %s: Pack, party, and "
    .. "251-species ROM-backed Pokédex presentation\n")
    :format(identity.profile.id))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result), "\n")
  os.exit(1)
end
os.exit(result)
