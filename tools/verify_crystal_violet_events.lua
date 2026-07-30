local CoverageReport = require("src.script.CoverageReport")
local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalTextData = require("src.import.CrystalTextData")
local CrystalWorldData = require("src.import.CrystalWorldData")
local GameSession = require("src.game.GameSession")
local MapPresentationRuntime =
  require("src.script.MapPresentationRuntime")
local MapScriptSession = require("src.script.MapScriptSession")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local ScriptCatalog = require("src.script.ScriptCatalog")
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
    error("M5-008 verification failed: " .. message, 2)
  end
end

local function mapStatus(report, id)
  for _, map in ipairs(report.maps) do
    if map.id == id then return map.status end
  end
end

local function drive(session, task, choose)
  local battle
  for _ = 1, 300 do
    if task.state == "completed" or task.state == "failed" then break end
    local active = session.dialogue.active
    if active and active.kind == "text" then
      session.dialogue:advance()
    elseif active and active.kind == "choice" then
      session.dialogue:choose(choose and choose(active)
        or "common.choice.yes")
    end
    if session.battles.active then
      battle = session.battles.active
      session.battles:resolve({
        outcome = "player_win",
        won = true,
      })
    end
    session:update(1)
  end
  requireValue(task.state == "completed",
    "script task failed or did not terminate: " .. tostring(task.error))
  return battle
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_violet_events.lua <path-to-ROM>\n"
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
  local textData = CrystalTextData.extract(rom, identity.profile)
  rom = nil

  local catalog = ScriptCatalog.load()
  local coverage = CoverageReport.generate(worldData, catalog)
  requireValue(coverage.summary.definitions == 21,
    "native definition count changed")
  requireValue(coverage.summary.mapScripts == 20,
    "map definition count changed")
  requireValue(coverage.summary.maps.covered == 20,
    "first-badge scripted map count changed")
  requireValue(coverage.summary.callbacks.implemented == 10,
    "callback coverage changed")
  requireValue(coverage.summary.scenes.implemented == 11,
    "scene coverage changed")
  for _, mapId in ipairs({
    "24:3", "26:1", "26:2", "26:3", "26:10",
    "10:1", "10:3", "10:5", "10:8",
  }) do
    requireValue(mapStatus(coverage, mapId) == "covered",
      "core map is not structurally covered: " .. mapId)
  end
  requireValue(textData.count == 96,
    "expanded player-ROM text catalog is incomplete")

  local game = GameSession.new(identity.profile.id)
  game.party:give(battleData.speciesIds[152], 5)
  local world = World.new(worldData)

  world:relocate("26:10", 4, 7, "up", "verification")
  local mrDefinition = catalog:forMap("26:10")
  local mrSession = MapScriptSession.new(world, mrDefinition, {
    gameSession = game,
    state = game.state,
    party = game.party,
    inventory = game.inventory,
    phone = game.phone,
  })
  local meeting = mrSession:run(
    "scenes",
    "crystal.mr_pokemon.scene.meeting"
  )
  drive(mrSession, meeting)
  requireValue(game.state:hasFlag("crystal.story.got_mystery_egg"),
    "Mr. Pokemon did not set the Mystery Egg story gate")
  requireValue(game.state:hasFlag("crystal.story.got_pokedex"),
    "Oak did not set the Pokedex story gate")
  requireValue(game.inventory:count("crystal.item.mystery_egg") == 1,
    "Mystery Egg was not persisted in the game session")

  world:relocate("26:3", 33, 6, "right", "verification")
  local cityDefinition = catalog:forMap("26:3")
  local citySession = MapScriptSession.new(world, cityDefinition, {
    gameSession = game,
    state = game.state,
    party = game.party,
    inventory = game.inventory,
    phone = game.phone,
  })
  local guide = citySession:run(
    "objects",
    "crystal.cherrygrove.object.guide"
  )
  drive(citySession, guide)
  requireValue(game.state:hasFlag("crystal.feature.map_card"),
    "guide tour did not persist the Map Card")
  local rival = citySession:run(
    "coordEvents",
    "crystal.cherrygrove.coord.rival_north"
  )
  local rivalRequest = drive(citySession, rival)
  requireValue(rivalRequest
      and rivalRequest.kind == "trainer"
      and rivalRequest.opponentId == "crystal.trainer.rival.lab",
    "Cherrygrove rival gate did not dispatch its trainer battle")
  requireValue(game.state:hasFlag(
      "crystal.story.beat_cherrygrove_rival"),
    "Cherrygrove rival result did not persist")

  world:relocate("10:1", 18, 8, "down", "verification")
  local route32Definition = catalog:forMap("10:1")
  local route32Session = MapScriptSession.new(world, route32Definition, {
    gameSession = game,
    state = game.state,
    party = game.party,
    inventory = game.inventory,
    phone = game.phone,
  })
  local guard = route32Session:run(
    "coordEvents",
    "crystal.route_32.coord.badge_guard"
  )
  drive(route32Session, guard)
  requireValue(world.player.y == 6,
    "pre-badge Route 32 guard did not return the player north")

  local visibleGame = GameSession.new(identity.profile.id)
  visibleGame.party:give(battleData.speciesIds[152], 5)
  local visibleWorld = World.new(worldData)
  local runtime = MapPresentationRuntime.new(visibleWorld, {
    gameSession = visibleGame,
    textCatalog = textData,
    battleBridge = {
      start = function()
        error("unexpected battle during entry-scene verification")
      end,
    },
  })
  visibleWorld:relocate("26:10", 4, 7, "up", "verification")
  local noInput = {
    down = function() return false end,
    wasPressed = function() return false end,
  }
  runtime:updateIdle(noInput)
  for _ = 1, 3 do
    if runtime.dialogue.active then break end
    runtime:updateActive(1, noInput)
  end
  requireValue(runtime.dialogue.active
      and runtime.dialogue.active.id
        == "crystal.text.mr_pokemon.intro_1",
    "visible map runtime did not start Mr. Pokemon's entry scene")

  print("Crystal M5-008 Violet event verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Definitions/maps: 21/20 (20 of 29 extracted maps scripted)")
  print("ROM dialogue: 96 semantic mappings")
  print("Story: Mystery Egg + Pokedex -> rival battle -> Violet")
  print("Boundary: Route 32 pre-badge guard verified on real collision")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
