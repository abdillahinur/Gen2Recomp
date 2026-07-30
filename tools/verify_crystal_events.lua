local CrystalWorldData = require("src.import.CrystalWorldData")
local IntroductionSession =
  require("src.script.IntroductionSession")
local MapPresentationRuntime =
  require("src.script.MapPresentationRuntime")
local Profiles = require("src.import.Profiles")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local ScriptCatalog = require("src.script.ScriptCatalog")
local ScriptState = require("src.script.ScriptState")
local PresentationController =
  require("src.ui.PresentationController")
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

local function input(action)
  return {
    wasPressed = function(_, candidate)
      return action == candidate
    end,
  }
end

local function driveIntroduction(session, task)
  local presentation = PresentationController.new({
    dialogue = session.dialogue,
    clock = session.clock,
    names = session.names,
  })
  local visible = {}
  local steps = 0
  while not finished(task) do
    steps = steps + 1
    requireValue(steps <= 100, "introduction did not finish")
    local model = presentation:model()
    requireValue(model ~= nil,
      "introduction wait has no visible presentation model")
    visible[model.kind] = true
    local active = session.dialogue.active
    if active and active.kind == "text" then
      presentation:update(input("confirm"))
    elseif active and active.kind == "choice" then
      requireValue(
        active.id == "crystal.choice.player_gender",
        "unexpected introduction choice " .. active.id
      )
      presentation:update(input("confirm"))
    elseif session.clock.active then
      session.clock:setTime(10, 30)
      presentation:update(input("confirm"))
    elseif session.names.active then
      if session.names.active.stage == "choices" then
        presentation:update(input("confirm"))
      else
        session.names:setCustom("NOVA")
        session.names:submitCustom()
      end
    end
    session:update(World.STEP_SECONDS)
  end
  requireCompleted(task, "introduction")
  return visible
end

local function driveMap(runtime, choices)
  local visible = {}
  local steps = 0
  while runtime:isBusy() do
    steps = steps + 1
    requireValue(steps <= 300, "map behavior did not finish")
    local model = runtime.presentation:model()
    if model then visible[model.kind] = true end
    local active = runtime.dialogue.active
    local action
    if active and active.kind == "text" then
      action = "confirm"
    elseif active and active.kind == "choice" then
      local option = choices[active.id]
      requireValue(option ~= nil, "unexpected map choice " .. active.id)
      local selected = active.options[1].id
      if selected == option then
        action = "confirm"
      else
        runtime.dialogue:choose(option)
      end
    end
    runtime:updateActive(World.STEP_SECONDS, input(action))
  end
  requireValue(runtime.lastError == nil,
    "map presentation runtime failed: " .. tostring(runtime.lastError))
  return visible
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
  local visibleIntroduction =
    driveIntroduction(introductionSession, introductionTask)
  for _, kind in ipairs({
    "choice",
    "clock",
    "text",
    "name_choice",
    "name_keyboard",
  }) do
    requireValue(visibleIntroduction[kind],
      "introduction did not expose visible " .. kind .. " presentation")
  end
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
  local runtime = MapPresentationRuntime.new(world, { state = state })
  world:relocate("24:5", 4, 11, "up", "m3_acceptance")
  runtime:updateIdle(input())
  local visibleElm = driveMap(runtime, {
    ["crystal.choice.elms_lab.help_elm"] = "common.choice.yes",
  })
  requireValue(visibleElm.text and visibleElm.choice,
    "Elm meeting did not expose visible text and choice presentation")
  requireValue(
    state:getScene("crystal.map.elms_lab")
      == "crystal.scene.elms_lab.cant_leave",
    "Elm meeting did not open starter selection"
  )
  requireValue(world.player.x == 4 and world.player.y == 4,
    "Elm meeting did not move the player to the expected tile")

  world:relocate("24:5", 6, 4, "up", "m3_starter")
  requireValue(runtime:updateIdle(input("confirm")),
    "starter object did not open an interaction")
  driveMap(runtime, {
    ["crystal.choice.elms_lab.take_cyndaquil"] = "common.choice.yes",
  })
  requireValue(state:hasFlag("crystal.story.got_starter"),
    "starter flag was not set")
  requireValue(
    state:hasFlag("crystal.story.got_cyndaquil_from_elm"),
    "species starter flag was not set"
  )
  local starter = runtime.party.members[1]
  requireValue(starter
      and starter.speciesId == "crystal.species.cyndaquil"
      and starter.level == 5
      and starter.heldItemId == "crystal.item.berry",
    "party did not receive the expected starter")
  requireValue(
    runtime.phone:has("crystal.phone.professor_elm"),
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
  requireValue(runtime:updateIdle(input()),
    "aide coordinate event did not start")
  driveMap(runtime, {})
  requireValue(
    runtime.inventory:count("crystal.item.potion") == 1,
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
  print("Presentation: text/choice/clock/naming models verified")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
