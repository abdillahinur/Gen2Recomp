local BattleRequestFactory =
  require("src.battle.BattleRequestFactory")
local CoreCommandHandlers =
  require("src.script.CoreCommandHandlers")
local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalWorldData = require("src.import.CrystalWorldData")
local DataRegistry = require("src.pokemon.DataRegistry")
local DialogueService = require("src.script.DialogueService")
local GameSession = require("src.game.GameSession")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local ScriptRunner = require("src.script.ScriptRunner")
local gym = require("data.scripts.crystal.maps.violet_gym")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then error("could not open ROM: " .. tostring(message), 2) end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-013 verification failed: " .. message, 2)
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then return 2 end
  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(data)
  data = nil
  local battleData =
    CrystalBattleData.extract(rom, identity.profile)
  local worldData =
    CrystalWorldData.extract(rom, identity.profile)
  rom = nil
  local falkner
  for _, trainer in ipairs(worldData.trainers.records) do
    if trainer.id == "crystal.trainer.01.001" then falkner = trainer end
  end
  requireValue(falkner and falkner.name == "FALKNER",
    "Falkner party was not decoded from the player ROM")
  requireValue(#falkner.party == 2
      and falkner.party[1].speciesNumber == 16
      and falkner.party[1].level == 7
      and falkner.party[2].speciesNumber == 17
      and falkner.party[2].level == 9,
    "Falkner's ROM party changed")

  local game = GameSession.new(identity.profile.id)
  game.party:give("crystal.species.cyndaquil", 12)
  local factory = BattleRequestFactory.new(
    DataRegistry.new(battleData), battleData, game, {
      trainers = worldData.trainers,
    })
  local battle = factory:create({
    kind = "trainer",
    opponentId = falkner.id,
    options = { aiProfileId = "battle.ai.smart" },
  })
  requireValue(
    battle.state.opponent.party[1].speciesId:match("pidgey$")
      and battle.state.opponent.party[2].speciesId:match("pidgeotto$"),
    "native battle did not construct Falkner's ROM party")

  local runner = ScriptRunner.new()
  local dialogue = DialogueService.new()
  CoreCommandHandlers.install(runner, {
    state = game.state,
    dialogue = dialogue,
  })
  runner:register("actor.face", function() return true end)
  runner:register("audio.sfx.play", function() return true end)
  runner:register("inventory.item.give", function(arguments)
    game.inventory:give(arguments.itemId, arguments.count)
    return true
  end)
  runner:register("gameplay.battle", function()
    return { outcome = "player_win", won = true }
  end)
  local task = runner:start(
    "falkner",
    gym.behavior.objects["crystal.violet_gym.object.falkner"]
  )
  for _ = 1, 100 do
    if task.state == "completed" or task.state == "failed" then break end
    if dialogue.active then dialogue:advance() end
    runner:update(1)
  end
  requireValue(task.state == "completed",
    "Falkner reward script did not complete")
  requireValue(game.state:hasFlag("crystal.badge.zephyr")
      and game.inventory:count("crystal.item.tm31") == 1,
    "badge/TM progression was not persisted")
  io.write(("M5-013 verified %s: Falkner, Zephyr Badge, and TM31\n")
    :format(identity.profile.id))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result), "\n")
  os.exit(1)
end
os.exit(result)
