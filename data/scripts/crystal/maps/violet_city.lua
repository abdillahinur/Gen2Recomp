local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local EARL = "crystal.violet.actor.earl"
local PP_UP = "crystal.violet.actor.pp_up"
local RARE_CANDY = "crystal.violet.actor.rare_candy"
local YES = "common.choice.yes"

local function callback()
  Commands.setFlag("crystal.world.flypoint.violet")
  if Commands.hasFlag("crystal.violet.earl_at_academy") then
    Commands.hideObject(EARL)
  end
  if Commands.hasFlag("crystal.violet.got_pp_up") then
    Commands.hideObject(PP_UP)
  end
  if Commands.hasFlag("crystal.violet.got_rare_candy") then
    Commands.hideObject(RARE_CANDY)
  end
end

local function earl()
  Commands.face(EARL, "down")
  Commands.text("crystal.text.violet.earl_asks_about_falkner")
  local answer = Commands.choice("crystal.choice.violet.beat_falkner", {
    { id = YES, textId = "common.text.yes" },
    { id = "common.choice.no", textId = "common.text.no" },
  })
  if answer == YES then
    Commands.text("crystal.text.violet.earl_very_nice")
    return
  end
  Commands.text("crystal.text.violet.earl_follow")
  Commands.setFlag("crystal.violet.earl_at_academy")
  Commands.text("crystal.text.violet.earl_at_academy")
  Commands.hideObject(EARL)
end

return {
  schema = 1,
  id = "crystal.maps.violet_city",
  game = "crystal",
  kind = "map",
  maps = { "10:5" },
  actors = {
    { id = EARL, mapId = "10:5", objectId = 1 },
    { id = PP_UP, mapId = "10:5", objectId = 7 },
    { id = RARE_CANDY, mapId = "10:5", objectId = 8 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/VioletCity.asm",
      {
        "VioletCity_MapScripts",
        "VioletCityFlypointCallback",
        "VioletCityEarlScript",
        "VioletCityLassScript",
        "VioletCitySuperNerdScript",
        "VioletCityGrampsScript",
        "VioletCityYoungsterScript",
      },
      "Used for flypoint state, Earl's academy guidance, city NPCs, fruit, items, and signs."
    ),
  },
  coverage = {
    callbacks = { "crystal.violet.callback.new_map" },
    scenes = {},
    coordEvents = {},
    bgEvents = {
      "crystal.violet.bg.city_sign",
      "crystal.violet.bg.gym_sign",
      "crystal.violet.bg.sprout_tower_sign",
      "crystal.violet.bg.academy_sign",
      "crystal.violet.bg.pokecenter_sign",
      "crystal.violet.bg.mart_sign",
      "crystal.violet.bg.hidden_hyper_potion",
    },
    objects = {
      "crystal.violet.object.earl",
      "crystal.violet.object.lass",
      "crystal.violet.object.super_nerd",
      "crystal.violet.object.gramps",
      "crystal.violet.object.youngster",
      "crystal.violet.object.fruit_tree",
      "crystal.violet.object.pp_up",
      "crystal.violet.object.rare_candy",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.violet.callback.new_map"] = callback,
    },
    scenes = {},
    coordEvents = {},
    bgEvents = {
      ["crystal.violet.bg.city_sign"] =
        Helpers.text("crystal.text.violet.city_sign"),
      ["crystal.violet.bg.gym_sign"] =
        Helpers.text("crystal.text.violet.gym_sign"),
      ["crystal.violet.bg.sprout_tower_sign"] =
        Helpers.text("crystal.text.violet.sprout_tower_sign"),
      ["crystal.violet.bg.academy_sign"] =
        Helpers.text("crystal.text.violet.academy_sign"),
      ["crystal.violet.bg.pokecenter_sign"] =
        Helpers.text("crystal.text.common.pokecenter_sign"),
      ["crystal.violet.bg.mart_sign"] =
        Helpers.text("crystal.text.common.mart_sign"),
      ["crystal.violet.bg.hidden_hyper_potion"] = Helpers.item(
        nil,
        "crystal.violet.got_hidden_hyper_potion",
        "crystal.item.hyper_potion"
      ),
    },
    objects = {
      ["crystal.violet.object.earl"] = earl,
      ["crystal.violet.object.lass"] =
        Helpers.text("crystal.text.violet.lass"),
      ["crystal.violet.object.super_nerd"] =
        Helpers.text("crystal.text.violet.super_nerd"),
      ["crystal.violet.object.gramps"] =
        Helpers.text("crystal.text.violet.gramps"),
      ["crystal.violet.object.youngster"] =
        Helpers.text("crystal.text.violet.youngster"),
      ["crystal.violet.object.fruit_tree"] =
        Helpers.fruit("crystal.violet.picked_fruit"),
      ["crystal.violet.object.pp_up"] = Helpers.item(
        PP_UP,
        "crystal.violet.got_pp_up",
        "crystal.item.pp_up"
      ),
      ["crystal.violet.object.rare_candy"] = Helpers.item(
        RARE_CANDY,
        "crystal.violet.got_rare_candy",
        "crystal.item.rare_candy"
      ),
    },
  },
}
