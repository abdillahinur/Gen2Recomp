local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local DUDE = "crystal.route_29.actor.tutorial_dude"
local TUSCANY = "crystal.route_29.actor.tuscany"
local POTION = "crystal.route_29.actor.potion"
local YES = "common.choice.yes"

local function callback()
  local weekday = Commands.getVariable("clock.weekday", -1)
  if Commands.hasFlag("crystal.badge.zephyr") and weekday == 2 then
    Commands.showObject(TUSCANY)
  else
    Commands.hideObject(TUSCANY)
  end
  if Commands.hasFlag("crystal.route_29.got_potion") then
    Commands.hideObject(POTION)
  end
end

local function tutorial()
  Commands.face(DUDE, "up")
  Commands.emote(DUDE, "common.emote.shock", 15 / 60)
  Commands.text("crystal.text.route_29.tutorial_intro")
  local answer = Commands.choice("crystal.choice.route_29.tutorial", {
    { id = YES, textId = "common.text.yes" },
    { id = "common.choice.no", textId = "common.text.no" },
  })
  if answer == YES then
    Commands.battle("wild", "crystal.species.019", {
      speciesNumber = 19,
      level = 5,
      tutorial = true,
    })
    Commands.setFlag("crystal.route_29.learned_to_catch")
    Commands.text("crystal.text.route_29.tutorial_debrief")
  else
    Commands.text("crystal.text.route_29.tutorial_declined")
  end
end

local function cooltrainer()
  local hour = Commands.getVariable("clock.hour", 10)
  Commands.text(hour >= 18
    and "crystal.text.route_29.waiting_for_morning"
    or "crystal.text.route_29.waiting_for_night")
end

local function tuscany()
  if Commands.hasFlag("crystal.route_29.got_pink_bow") then
    Commands.text("crystal.text.route_29.tuscany_after")
    return
  end
  Commands.text("crystal.text.route_29.tuscany_intro")
  Commands.giveItem("crystal.item.pink_bow", 1)
  Commands.setFlag("crystal.route_29.got_pink_bow")
  Commands.text("crystal.text.route_29.tuscany_gift")
end

return {
  schema = 1,
  id = "crystal.maps.route_29",
  game = "crystal",
  kind = "map",
  maps = { "24:3" },
  automaticCoordEvents = true,
  actors = {
    { id = DUDE, mapId = "24:3", objectId = 1 },
    { id = TUSCANY, mapId = "24:3", objectId = 7 },
    { id = POTION, mapId = "24:3", objectId = 8 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/Route29.asm",
      {
        "Route29_MapScripts",
        "Route29TuscanyCallback",
        "Route29Tutorial1",
        "CatchingTutorialDudeScript",
      },
      "Used for tutorial branching, time-aware NPC behavior, items, fruit, and route interactions."
    ),
  },
  coverage = {
    callbacks = { "crystal.route_29.callback.objects" },
    scenes = {},
    coordEvents = {
      "crystal.route_29.coord.tutorial_north",
      "crystal.route_29.coord.tutorial_south",
    },
    bgEvents = {
      "crystal.route_29.bg.sign_east",
      "crystal.route_29.bg.sign_west",
    },
    objects = {
      "crystal.route_29.object.tutorial_dude",
      "crystal.route_29.object.youngster",
      "crystal.route_29.object.teacher",
      "crystal.route_29.object.fruit_tree",
      "crystal.route_29.object.fisher",
      "crystal.route_29.object.cooltrainer",
      "crystal.route_29.object.tuscany",
      "crystal.route_29.object.potion",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.route_29.callback.objects"] = callback,
    },
    scenes = {},
    coordEvents = {
      ["crystal.route_29.coord.tutorial_north"] = tutorial,
      ["crystal.route_29.coord.tutorial_south"] = tutorial,
    },
    bgEvents = {
      ["crystal.route_29.bg.sign_east"] =
        Helpers.text("crystal.text.route_29.sign"),
      ["crystal.route_29.bg.sign_west"] =
        Helpers.text("crystal.text.route_29.sign"),
    },
    objects = {
      ["crystal.route_29.object.tutorial_dude"] = tutorial,
      ["crystal.route_29.object.youngster"] =
        Helpers.text("crystal.text.route_29.youngster"),
      ["crystal.route_29.object.teacher"] =
        Helpers.text("crystal.text.route_29.teacher"),
      ["crystal.route_29.object.fruit_tree"] =
        Helpers.fruit("crystal.route_29.picked_fruit"),
      ["crystal.route_29.object.fisher"] =
        Helpers.text("crystal.text.route_29.fisher"),
      ["crystal.route_29.object.cooltrainer"] = cooltrainer,
      ["crystal.route_29.object.tuscany"] = tuscany,
      ["crystal.route_29.object.potion"] = Helpers.item(
        POTION,
        "crystal.route_29.got_potion",
        "crystal.item.potion"
      ),
    },
  },
}
