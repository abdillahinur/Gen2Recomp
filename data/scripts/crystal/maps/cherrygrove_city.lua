local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local GUIDE = "crystal.cherrygrove.actor.guide"
local RIVAL = "crystal.cherrygrove.actor.rival"
local YES = "common.choice.yes"

local function callback()
  Commands.setFlag("crystal.world.flypoint.cherrygrove")
  if Commands.hasFlag("crystal.feature.map_card") then
    Commands.hideObject(GUIDE)
  else
    Commands.showObject(GUIDE)
  end
  if Commands.hasFlag("crystal.story.got_pokedex")
      and not Commands.hasFlag("crystal.story.beat_cherrygrove_rival") then
    Commands.showObject(RIVAL)
  else
    Commands.hideObject(RIVAL)
  end
end

local function guide()
  Commands.face(GUIDE, "left")
  Commands.text("crystal.text.cherrygrove.guide_intro")
  local answer = Commands.choice("crystal.choice.cherrygrove.guide", {
    { id = YES, textId = "common.text.yes" },
    { id = "common.choice.no", textId = "common.text.no" },
  })
  if answer ~= YES then
    Commands.text("crystal.text.cherrygrove.guide_no")
    return
  end
  Commands.text("crystal.text.cherrygrove.guide_tour")
  Commands.playMusic("crystal.music.show_me_around")
  Commands.text("crystal.text.cherrygrove.guide_pokecenter")
  Commands.text("crystal.text.cherrygrove.guide_mart")
  Commands.text("crystal.text.cherrygrove.guide_route_30")
  Commands.text("crystal.text.cherrygrove.guide_sea")
  Commands.text("crystal.text.cherrygrove.guide_gift")
  Commands.setFlag("crystal.feature.map_card")
  Commands.text("crystal.text.cherrygrove.got_map_card")
  Commands.text("crystal.text.cherrygrove.guide_pokegear")
  Commands.hideObject(GUIDE)
  Commands.playMusic("crystal.music.cherrygrove_city")
end

local function rival()
  if not Commands.hasFlag("crystal.story.got_pokedex")
      or Commands.hasFlag("crystal.story.beat_cherrygrove_rival") then
    return
  end
  Commands.face(RIVAL, "left")
  Commands.emote("common.actor.player", "common.emote.shock", 15 / 60)
  Commands.playMusic("crystal.music.rival_encounter")
  Commands.text("crystal.text.cherrygrove.rival_seen")
  local result = Commands.battle(
    "trainer",
    "crystal.trainer.rival.lab",
    { canLose = true }
  )
  Commands.text(result.won
    and "crystal.text.cherrygrove.rival_won"
    or "crystal.text.cherrygrove.rival_lost")
  Commands.setFlag("crystal.story.beat_cherrygrove_rival")
  Commands.playSfx("crystal.sfx.tackle")
  Commands.hideObject(RIVAL)
  Commands.playMusic("crystal.music.cherrygrove_city")
end

local function teacher()
  Commands.text(Commands.hasFlag("crystal.feature.map_card")
    and "crystal.text.cherrygrove.teacher_has_map"
    or "crystal.text.cherrygrove.teacher_needs_map")
end

local function youngster()
  Commands.text(Commands.hasFlag("crystal.story.got_pokedex")
    and "crystal.text.cherrygrove.youngster_has_pokedex"
    or "crystal.text.cherrygrove.youngster_no_pokedex")
end

return {
  schema = 1,
  id = "crystal.maps.cherrygrove_city",
  game = "crystal",
  kind = "map",
  maps = { "26:3" },
  automaticCoordEvents = true,
  actors = {
    { id = GUIDE, mapId = "26:3", objectId = 1 },
    { id = RIVAL, mapId = "26:3", objectId = 2 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/CherrygroveCity.asm",
      {
        "CherrygroveCity_MapScripts",
        "CherrygroveCityFlypointCallback",
        "CherrygroveCityGuideGent",
        "CherrygroveRivalSceneNorth",
        "CherrygroveRivalSceneSouth",
      },
      "Used for the guide tour, Map Card, rival gate and battle, flypoint, NPC branches, and signs."
    ),
  },
  coverage = {
    callbacks = { "crystal.cherrygrove.callback.new_map" },
    scenes = {
      "crystal.cherrygrove.scene.rival_north",
      "crystal.cherrygrove.scene.rival_south",
    },
    coordEvents = {
      "crystal.cherrygrove.coord.rival_north",
      "crystal.cherrygrove.coord.rival_south",
    },
    bgEvents = {
      "crystal.cherrygrove.bg.city_sign",
      "crystal.cherrygrove.bg.guide_house_sign",
      "crystal.cherrygrove.bg.mart_sign",
      "crystal.cherrygrove.bg.pokecenter_sign",
    },
    objects = {
      "crystal.cherrygrove.object.guide",
      "crystal.cherrygrove.object.rival",
      "crystal.cherrygrove.object.teacher",
      "crystal.cherrygrove.object.youngster",
      "crystal.cherrygrove.object.fisher",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.cherrygrove.callback.new_map"] = callback,
    },
    scenes = {
      ["crystal.cherrygrove.scene.rival_north"] = rival,
      ["crystal.cherrygrove.scene.rival_south"] = rival,
    },
    coordEvents = {
      ["crystal.cherrygrove.coord.rival_north"] = rival,
      ["crystal.cherrygrove.coord.rival_south"] = rival,
    },
    bgEvents = {
      ["crystal.cherrygrove.bg.city_sign"] =
        Helpers.text("crystal.text.cherrygrove.city_sign"),
      ["crystal.cherrygrove.bg.guide_house_sign"] =
        Helpers.text("crystal.text.cherrygrove.guide_house_sign"),
      ["crystal.cherrygrove.bg.mart_sign"] =
        Helpers.text("crystal.text.common.mart_sign"),
      ["crystal.cherrygrove.bg.pokecenter_sign"] =
        Helpers.text("crystal.text.common.pokecenter_sign"),
    },
    objects = {
      ["crystal.cherrygrove.object.guide"] = guide,
      ["crystal.cherrygrove.object.rival"] = rival,
      ["crystal.cherrygrove.object.teacher"] = teacher,
      ["crystal.cherrygrove.object.youngster"] = youngster,
      ["crystal.cherrygrove.object.fisher"] =
        Helpers.text("crystal.text.cherrygrove.fisher"),
    },
  },
}
