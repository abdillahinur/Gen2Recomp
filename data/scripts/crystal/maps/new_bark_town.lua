local Commands = require("src.script.Commands")
local Provenance = require("data.scripts.Provenance")

local PLAYER = "common.actor.player"
local TEACHER = "crystal.new_bark.actor.teacher"
local FISHER = "crystal.new_bark.actor.fisher"
local RIVAL = "crystal.new_bark.actor.rival"

local function newMap()
  Commands.setFlag("crystal.world.flypoint.new_bark")
  Commands.clearFlag("crystal.story.first_time_banking_with_mom")
end

local function teacherStops(extraStep)
  Commands.playMusic("crystal.music.mom")
  Commands.face(TEACHER, "left")
  Commands.text("crystal.text.new_bark.wait")
  Commands.face(PLAYER, "right")
  local towardPlayer = { "left", "left", "left", "left" }
  if extraStep then towardPlayer[#towardPlayer + 1] = "left" end
  Commands.move(TEACHER, towardPlayer)
  if extraStep then Commands.face(PLAYER, "up") end
  Commands.text("crystal.text.new_bark.what_are_you_doing")
  Commands.follow(PLAYER, TEACHER)
  local returnHome = { "right", "right", "right", "right" }
  if extraStep then returnHome[#returnHome + 1] = "right" end
  Commands.move(TEACHER, returnHome)
  Commands.stopFollowing(PLAYER)
  Commands.face(TEACHER, "left")
  Commands.text("crystal.text.new_bark.dangerous_without_pokemon")
  Commands.playMusic("crystal.music.new_bark_town")
end

local function teacherStopsNorth()
  teacherStops(false)
end

local function teacherStopsSouth()
  teacherStops(true)
end

local function teacherInteraction()
  Commands.face(TEACHER, "left")
  local textId = "crystal.text.new_bark.gear_is_impressive"
  if Commands.hasFlag("crystal.story.talked_to_mom_after_egg") then
    textId = "crystal.text.new_bark.call_mom"
  elseif Commands.hasFlag("crystal.story.gave_mystery_egg_to_elm") then
    textId = "crystal.text.new_bark.tell_mom_before_leaving"
  elseif Commands.hasFlag("crystal.story.got_starter") then
    textId = "crystal.text.new_bark.pokemon_is_adorable"
  end
  Commands.text(textId)
end

local function fisherInteraction()
  Commands.text("crystal.text.new_bark.elm_discovered_pokemon")
end

local function rivalInteraction()
  Commands.text("crystal.text.new_bark.rival_observes_lab")
  Commands.face(RIVAL, "left")
  Commands.text("crystal.text.new_bark.rival_confronts_player")
  Commands.follow(RIVAL, PLAYER)
  Commands.move(PLAYER, { "down" })
  Commands.stopFollowing(RIVAL)
  Commands.pause(5 / 60)
  Commands.face(RIVAL, "down")
  Commands.pause(5 / 60)
  Commands.playSfx("crystal.sfx.tackle")
  Commands.move(PLAYER, { "down" })
  Commands.move(RIVAL, { "right" })
end

local function text(id)
  return function() Commands.text(id) end
end

return {
  schema = 1,
  id = "crystal.maps.new_bark_town",
  game = "crystal",
  kind = "map",
  maps = { "24:4" },
  actors = {
    { id = TEACHER, mapId = "24:4", objectId = 1 },
    { id = FISHER, mapId = "24:4", objectId = 2 },
    { id = RIVAL, mapId = "24:4", objectId = 3 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/NewBarkTown.asm",
      {
        "NewBarkTown_MapScripts",
        "NewBarkTownFlypointCallback",
        "NewBarkTown_TeacherStopsYouScene1",
        "NewBarkTown_TeacherStopsYouScene2",
        "NewBarkTownTeacherScript",
        "NewBarkTownFisherScript",
        "NewBarkTownRivalScript",
      },
      "Used to reproduce the map callback, east-exit guard, NPC branches, rival shove, and sign interactions."
    ),
  },
  coverage = {
    callbacks = { "crystal.new_bark.callback.new_map" },
    scenes = {
      "crystal.new_bark.scene.teacher_north",
      "crystal.new_bark.scene.teacher_south",
    },
    coordEvents = {
      "crystal.new_bark.coord.teacher_north",
      "crystal.new_bark.coord.teacher_south",
    },
    bgEvents = {
      "crystal.new_bark.bg.town_sign",
      "crystal.new_bark.bg.player_house_sign",
      "crystal.new_bark.bg.elm_lab_sign",
      "crystal.new_bark.bg.elm_house_sign",
    },
    objects = {
      "crystal.new_bark.object.teacher",
      "crystal.new_bark.object.fisher",
      "crystal.new_bark.object.rival",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.new_bark.callback.new_map"] = newMap,
    },
    scenes = {
      ["crystal.new_bark.scene.teacher_north"] = teacherStopsNorth,
      ["crystal.new_bark.scene.teacher_south"] = teacherStopsSouth,
    },
    coordEvents = {
      ["crystal.new_bark.coord.teacher_north"] = teacherStopsNorth,
      ["crystal.new_bark.coord.teacher_south"] = teacherStopsSouth,
    },
    bgEvents = {
      ["crystal.new_bark.bg.town_sign"] =
        text("crystal.text.new_bark.town_sign"),
      ["crystal.new_bark.bg.player_house_sign"] =
        text("crystal.text.new_bark.player_house_sign"),
      ["crystal.new_bark.bg.elm_lab_sign"] =
        text("crystal.text.new_bark.elm_lab_sign"),
      ["crystal.new_bark.bg.elm_house_sign"] =
        text("crystal.text.new_bark.elm_house_sign"),
    },
    objects = {
      ["crystal.new_bark.object.teacher"] = teacherInteraction,
      ["crystal.new_bark.object.fisher"] = fisherInteraction,
      ["crystal.new_bark.object.rival"] = rivalInteraction,
    },
  },
}
