local GameSession = require("src.game.GameSession")
local IntroductionSession =
  require("src.script.IntroductionSession")
local MapRepository = require("src.world.MapRepository")
local MapScriptSession = require("src.script.MapScriptSession")
local World = require("src.world.World")

local introduction =
  require("data.scripts.crystal.flows.introduction")
local elmsLab =
  require("data.scripts.crystal.maps.elms_lab")
local mrPokemon =
  require("data.scripts.crystal.maps.mr_pokemons_house")
local cherrygrove =
  require("data.scripts.crystal.maps.cherrygrove_city")
local violetGym =
  require("data.scripts.crystal.maps.violet_gym")

local VerticalSliceRoute = {}

local function textEntry(catalog, id)
  local alias = catalog.aliases and catalog.aliases[id]
  return catalog.entries[id] or alias and catalog.entries[alias]
end

local function requireText(catalog, seen, id)
  if not textEntry(catalog, id) then
    error("vertical slice route used semantic fallback text: " .. id, 3)
  end
  seen[id] = true
end

local function finishIntroduction(catalog, seen)
  local session = IntroductionSession.new(introduction)
  session:start()
  for _ = 1, 500 do
    if session.task.state == "completed" then break end
    local dialogue = session.dialogue.active
    if dialogue and dialogue.kind == "choice" then
      session.dialogue:choose("crystal.profile.gender.boy")
    elseif dialogue then
      requireText(catalog, seen, dialogue.id)
      session.dialogue:advance()
    elseif session.clock.active then
      session.clock:setTime(10, 0)
      session.clock:confirm()
    elseif session.names.active then
      local request = session.names.active
      local preset = request.presets and request.presets[1]
      if preset then
        session.names:choosePreset(preset.id)
      else
        session.names:beginCustom()
        session.names:setCustom("GOLD")
        session.names:submitCustom()
      end
    end
    session:update(0.25)
  end
  if session.task.state ~= "completed" then
    error("vertical slice introduction did not complete", 2)
  end
  return session
end

local function mapSession(world, game, definition)
  return MapScriptSession.new(world, definition, {
      state = game.state,
      party = game.party,
      inventory = game.inventory,
      phone = game.phone,
    })
end

local function runMap(session, catalog, seen, kind, id)
  local task = session:run(kind, id)
  for _ = 1, 1000 do
    if task.state == "completed" or task.state == "failed" then break end
    local dialogue = session.dialogue.active
    if dialogue and dialogue.kind == "text" then
      requireText(catalog, seen, dialogue.id)
      session.dialogue:advance()
    elseif dialogue and dialogue.kind == "choice" then
      session.dialogue:choose("common.choice.yes")
    end
    if session.battles.active then
      session.battles:resolve({
        outcome = "player_win",
        won = true,
      })
    end
    session:update(0.25)
  end
  if task.state ~= "completed" then
    error("vertical slice behavior failed: "
      .. session.definition.id .. "/" .. id .. ": "
      .. tostring(task.error), 2)
  end
end

local function requireMaps(repository)
  for _, id in ipairs({
    "24:4", "24:5", "24:3", "26:3", "26:1",
    "26:10", "26:2", "10:5", "10:7", "10:1",
  }) do
    if not repository:getMap(id) then
      error("vertical slice route map is unavailable: " .. id, 2)
    end
  end
end

function VerticalSliceRoute.run(worldData, textCatalog)
  local seen = {}
  local intro = finishIntroduction(textCatalog, seen)
  local game = GameSession.new(textCatalog.profileId, {
    state = intro.state,
  })
  local repository = MapRepository.new(worldData)
  requireMaps(repository)
  local world = World.new(worldData, { repository = repository })

  world:relocate("24:5", 4, 8, "up", "acceptance")
  local elmSession = mapSession(world, game, elmsLab)
  runMap(
    elmSession, textCatalog, seen, "scenes",
    "crystal.elms_lab.scene.meet_elm")
  runMap(
    elmSession, textCatalog, seen, "objects",
    "crystal.elms_lab.object.cyndaquil_ball")

  world:relocate("26:10", 4, 7, "up", "acceptance")
  runMap(
    mapSession(world, game, mrPokemon),
    textCatalog, seen, "scenes",
    "crystal.mr_pokemon.scene.meeting")

  world:relocate("26:3", 5, 6, "right", "acceptance")
  runMap(
    mapSession(world, game, cherrygrove),
    textCatalog, seen, "coordEvents",
    "crystal.cherrygrove.coord.rival_north")

  world:relocate("10:7", 5, 2, "up", "acceptance")
  runMap(
    mapSession(world, game, violetGym),
    textCatalog, seen, "objects",
    "crystal.violet_gym.object.falkner")
  game:captureWorld(world)

  if not game.state:hasFlag("crystal.story.introduction_complete")
      or not game.state:hasFlag("crystal.story.got_starter")
      or not game.state:hasFlag("crystal.story.got_pokedex")
      or not game.state:hasFlag("crystal.story.beat_cherrygrove_rival")
      or not game.state:hasFlag("crystal.badge.zephyr")
      or game.inventory:count("crystal.item.tm31") ~= 1 then
    error("vertical slice route did not reach its progression gate", 2)
  end

  local count = 0
  for _ in pairs(seen) do count = count + 1 end
  return {
    game = game,
    world = world,
    textIds = seen,
    textCount = count,
    stages = {
      "introduction",
      "elm_and_starter",
      "mr_pokemon_and_pokedex",
      "cherrygrove_rival",
      "violet_and_falkner",
    },
  }
end

return VerticalSliceRoute
