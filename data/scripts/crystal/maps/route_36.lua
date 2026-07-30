local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local TREE = "crystal.route_36.actor.sudowoodo"
local ARTHUR = "crystal.route_36.actor.arthur"
local FLORIA = "crystal.route_36.actor.floria"
local SUICUNE = "crystal.route_36.actor.suicune"
local YES = "common.choice.yes"

local function callback()
  if Commands.getVariable("clock.weekday", -1) == 4 then
    Commands.showObject(ARTHUR)
  else
    Commands.hideObject(ARTHUR)
  end
  if Commands.hasFlag("crystal.story.fought_sudowoodo") then
    Commands.hideObject(TREE)
  end
  if Commands.hasFlag("crystal.story.saw_route_36_suicune") then
    Commands.hideObject(SUICUNE)
  end
end

local function suicune()
  if Commands.hasFlag("crystal.story.saw_route_36_suicune") then return end
  Commands.emote("common.actor.player", "common.emote.shock", 15 / 60)
  Commands.playSfx("crystal.sfx.warp")
  Commands.hideObject(SUICUNE)
  Commands.setFlag("crystal.story.saw_route_36_suicune")
end

local function sudowoodo()
  if not Commands.hasFlag("crystal.feature.squirt_bottle") then
    Commands.playSfx("crystal.sfx.sandstorm")
    Commands.text("crystal.text.route_36.weird_tree")
    return
  end
  Commands.text("crystal.text.route_36.use_squirt_bottle")
  local answer = Commands.choice(
    "crystal.choice.route_36.use_squirt_bottle",
    {
      { id = YES, textId = "common.text.yes" },
      { id = "common.choice.no", textId = "common.text.no" },
    }
  )
  if answer ~= YES then return end
  Commands.text("crystal.text.route_36.sudowoodo_attacks")
  Commands.battle("wild", "crystal.species.185", {
    speciesNumber = 185,
    level = 20,
  })
  Commands.setFlag("crystal.story.fought_sudowoodo")
  Commands.hideObject(TREE)
end

local function arthur()
  if not Commands.hasFlag("crystal.route_36.got_hard_stone") then
    Commands.text("crystal.text.route_36.arthur_intro")
    Commands.giveItem("crystal.item.hard_stone", 1)
    Commands.setFlag("crystal.route_36.got_hard_stone")
  end
  Commands.text("crystal.text.route_36.arthur_after")
end

return {
  schema = 1,
  id = "crystal.maps.route_36",
  game = "crystal",
  kind = "map",
  maps = { "10:3" },
  automaticCoordEvents = true,
  actors = {
    { id = TREE, mapId = "10:3", objectId = 3 },
    { id = ARTHUR, mapId = "10:3", objectId = 7 },
    { id = FLORIA, mapId = "10:3", objectId = 8 },
    { id = SUICUNE, mapId = "10:3", objectId = 9 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/Route36.asm",
      {
        "Route36_MapScripts",
        "Route36ArthurCallback",
        "Route36SuicuneScript",
        "SudowoodoScript",
        "Route36FloriaScript",
      },
      "Used for route boundary events, trainers, weekday gift, fruit, NPCs, and signs."
    ),
  },
  coverage = {
    callbacks = { "crystal.route_36.callback.objects" },
    scenes = {
      "crystal.route_36.scene.suicune_left",
      "crystal.route_36.scene.suicune_right",
    },
    coordEvents = {
      "crystal.route_36.coord.suicune_left",
      "crystal.route_36.coord.suicune_right",
    },
    bgEvents = {
      "crystal.route_36.bg.trainer_tips_stats",
      "crystal.route_36.bg.ruins_sign",
      "crystal.route_36.bg.route_sign",
      "crystal.route_36.bg.trainer_tips_dig",
    },
    objects = {
      "crystal.route_36.object.mark",
      "crystal.route_36.object.alan",
      "crystal.route_36.object.sudowoodo",
      "crystal.route_36.object.lass",
      "crystal.route_36.object.rock_smash_guy",
      "crystal.route_36.object.fruit_tree",
      "crystal.route_36.object.arthur",
      "crystal.route_36.object.floria",
      "crystal.route_36.object.suicune",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.route_36.callback.objects"] = callback,
    },
    scenes = {
      ["crystal.route_36.scene.suicune_left"] = suicune,
      ["crystal.route_36.scene.suicune_right"] = suicune,
    },
    coordEvents = {
      ["crystal.route_36.coord.suicune_left"] = suicune,
      ["crystal.route_36.coord.suicune_right"] = suicune,
    },
    bgEvents = {
      ["crystal.route_36.bg.trainer_tips_stats"] =
        Helpers.text("crystal.text.route_36.trainer_tips_stats"),
      ["crystal.route_36.bg.ruins_sign"] =
        Helpers.text("crystal.text.route_36.ruins_sign"),
      ["crystal.route_36.bg.route_sign"] =
        Helpers.text("crystal.text.route_36.route_sign"),
      ["crystal.route_36.bg.trainer_tips_dig"] =
        Helpers.text("crystal.text.route_36.trainer_tips_dig"),
    },
    objects = {
      ["crystal.route_36.object.mark"] = Helpers.trainer(
        "crystal.trainer.52.007", 1088,
        "crystal.text.route_36.mark_after"),
      ["crystal.route_36.object.alan"] = Helpers.trainer(
        "crystal.trainer.23.003", 1134,
        "crystal.text.route_36.alan_after"),
      ["crystal.route_36.object.sudowoodo"] = sudowoodo,
      ["crystal.route_36.object.lass"] =
        Helpers.text("crystal.text.route_36.lass"),
      ["crystal.route_36.object.rock_smash_guy"] =
        Helpers.text("crystal.text.route_36.rock_smash_guy"),
      ["crystal.route_36.object.fruit_tree"] =
        Helpers.fruit("crystal.route_36.picked_fruit"),
      ["crystal.route_36.object.arthur"] = arthur,
      ["crystal.route_36.object.floria"] =
        Helpers.text("crystal.text.route_36.floria"),
      ["crystal.route_36.object.suicune"] = suicune,
    },
  },
}
