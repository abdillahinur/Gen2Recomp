local CrystalWorldData = require("src.import.CrystalWorldData")
local IntroductionSession =
  require("src.script.IntroductionSession")
local MapScriptSession = require("src.script.MapScriptSession")
local Profiles = require("src.import.Profiles")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local ScriptCatalog = require("src.script.ScriptCatalog")
local ScriptState = require("src.script.ScriptState")
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
    error("M3 verification failed: " .. message, 2)
  end
end

local function finished(task)
  return task.state == "completed"
    or task.state == "failed"
    or task.state == "cancelled"
end

local function requireCompleted(task, label)
  requireValue(
    task.state == "completed",
    label .. " ended in " .. task.state
      .. (task.error and (": " .. task.error) or "")
  )
end

local function driveIntroduction(session, task)
  local steps = 0
  while not finished(task) do
    steps = steps + 1
    requireValue(steps <= 100, "introduction did not finish")
    local active = session.dialogue.active
    if active and active.kind == "text" then
      session.dialogue:advance()
    elseif active and active.kind == "choice" then
      requireValue(
        active.id == "crystal.choice.player_gender",
        "unexpected introduction choice " .. active.id
      )
      session.dialogue:choose("crystal.profile.gender.boy")
    elseif session.clock.active then
      session.clock:setTime(10, 30)
      session.clock:confirm()
    elseif session.names.active then
      if session.names.active.stage == "choices" then
        session.names:beginCustom()
      else
        session.names:setCustom("NOVA")
        session.names:submitCustom()
      end
    end
    session:update(World.STEP_SECONDS)
  end
  requireCompleted(task, "introduction")
end

local function driveMap(session, task, choices)
  local steps = 0
  while not finished(task) do
    steps = steps + 1
    requireValue(steps <= 300, "map behavior did not finish")
    local active = session.dialogue.active
    if active and active.kind == "text" then
      session.dialogue:advance()
    elseif active and active.kind == "choice" then
      local option = choices[active.id]
      requireValue(option ~= nil, "unexpected map choice " .. active.id)
      session.dialogue:choose(option)
    end
    session:update(World.STEP_SECONDS)
  end
  requireCompleted(task, "map behavior")
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_events.lua <path-to-ROM>\n"
    )
    return 2
  end

  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  requireValue(identity.profile.id == "crystal_us_11",
    "this M3 checkpoint expects canonical Crystal US v1.1")
  requireValue(Profiles.get(identity.profile.id) == identity.profile,
    "profile registry changed during verification")
  local worldData =
    CrystalWorldData.extract(Rom.new(data), identity.profile)
  data = nil

  local catalog = ScriptCatalog.load()
  local introduction = catalog:get("crystal.flows.introduction")
  local elm = catalog:forMap("24:5")
  requireValue(introduction ~= nil, "introduction script is unavailable")
  requireValue(elm and elm.id == "crystal.maps.elms_lab",
    "Elm's Lab script is unavailable")

  local state = ScriptState.new()
  local introductionSession =
    IntroductionSession.new(introduction, { state = state })
  local introductionTask = introductionSession:start()
  driveIntroduction(introductionSession, introductionTask)
  requireValue(
    state:hasFlag("crystal.story.introduction_complete"),
    "introduction completion flag was not set"
  )
  requireValue(state:getVariable("player.name") == "NOVA",
    "custom player name was not retained")
  requireValue(state:getVariable("player.gender") == "male",
    "player gender was not retained")
  requireValue(state:getVariable("clock.hour") == 10
      and state:getVariable("clock.minute") == 30,
    "clock selection was not retained")

  local world = World.new(worldData)
  world:relocate("24:5", 4, 11, "up", "m3_acceptance")
  local mapSession = MapScriptSession.new(world, elm, { state = state })
  state:setScene(
    "crystal.map.elms_lab",
    "crystal.scene.elms_lab.meet_elm"
  )
  driveMap(
    mapSession,
    mapSession:run("callbacks", "crystal.elms_lab.callback.objects"),
    {}
  )
  driveMap(
    mapSession,
    mapSession:run("scenes", "crystal.elms_lab.scene.meet_elm"),
    {
      ["crystal.choice.elms_lab.help_elm"] = "common.choice.yes",
    }
  )
  requireValue(
    state:getScene("crystal.map.elms_lab")
      == "crystal.scene.elms_lab.cant_leave",
    "Elm meeting did not open starter selection"
  )
  requireValue(world.player.x == 4 and world.player.y == 4,
    "Elm meeting did not move the player to the expected tile")

  world:relocate("24:5", 6, 4, "up", "m3_starter")
  local starterTask = mapSession:run(
    "objects",
    "crystal.elms_lab.object.cyndaquil_ball"
  )
  driveMap(mapSession, starterTask, {
    ["crystal.choice.elms_lab.take_cyndaquil"] = "common.choice.yes",
  })
  requireValue(starterTask.result == "cyndaquil",
    "starter selection returned the wrong species")
  requireValue(state:hasFlag("crystal.story.got_starter"),
    "starter flag was not set")
  requireValue(
    state:hasFlag("crystal.story.got_cyndaquil_from_elm"),
    "species starter flag was not set"
  )
  local starter = mapSession.party.members[1]
  requireValue(starter
      and starter.speciesId == "crystal.species.cyndaquil"
      and starter.level == 5
      and starter.heldItemId == "crystal.item.berry",
    "party did not receive the expected starter")
  requireValue(
    mapSession.phone:has("crystal.phone.professor_elm"),
    "Elm phone contact was not registered"
  )
  requireValue(
    world.actors:state("crystal.elms_lab.actor.cyndaquil_ball").visible
      == false,
    "selected starter ball remained visible"
  )
  requireValue(
    state:getScene("crystal.map.elms_lab")
      == "crystal.scene.elms_lab.aide_gives_potion",
    "starter sequence did not enable the aide handoff"
  )

  world:relocate("24:5", 4, 8, "up", "m3_aide")
  driveMap(
    mapSession,
    mapSession:run(
      "coordEvents",
      "crystal.elms_lab.coord.aide_potion_left"
    ),
    {}
  )
  requireValue(
    mapSession.inventory:count("crystal.item.potion") == 1,
    "aide did not grant one Potion"
  )
  requireValue(
    state:getScene("crystal.map.elms_lab")
      == "crystal.scene.elms_lab.noop",
    "aide handoff did not close the lab scene"
  )

  print("Crystal M3 event verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Introduction: male/NOVA 10:30 complete")
  print("Elm meeting: accepted and starter selection opened")
  print("Starter: Cyndaquil level 5 holding Berry")
  print("Progression: Elm phone registered; Potion received")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
