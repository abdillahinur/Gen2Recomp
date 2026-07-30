local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local ANTIDOTE = "crystal.route_30.actor.antidote"

local function callback()
  if Commands.hasFlag("crystal.route_30.got_antidote") then
    Commands.hideObject(ANTIDOTE)
  end
end

local function youngster()
  Commands.text(Commands.hasFlag("crystal.story.gave_mystery_egg_to_elm")
    and "crystal.text.route_30.everyone_battling"
    or "crystal.text.route_30.directions")
end

return {
  schema = 1,
  id = "crystal.maps.route_30",
  game = "crystal",
  kind = "map",
  maps = { "26:1" },
  actors = {
    { id = ANTIDOTE, mapId = "26:1", objectId = 11 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/Route30.asm",
      {
        "Route30_MapScripts",
        "YoungsterJoey_ImportantBattleScript",
        "TrainerYoungsterJoey",
        "TrainerYoungsterMikey",
        "TrainerBugCatcherDon",
        "Route30YoungsterScript",
      },
      "Used for route NPC branches, trainer post-battle interactions, fruit, visible and hidden items, and signs."
    ),
  },
  coverage = {
    callbacks = { "crystal.route_30.callback.objects" },
    scenes = {},
    coordEvents = {},
    bgEvents = {
      "crystal.route_30.bg.sign",
      "crystal.route_30.bg.mr_pokemon_directions",
      "crystal.route_30.bg.mr_pokemon_house",
      "crystal.route_30.bg.trainer_tips",
      "crystal.route_30.bg.hidden_potion",
    },
    objects = {
      "crystal.route_30.object.youngster",
      "crystal.route_30.object.joey",
      "crystal.route_30.object.mikey",
      "crystal.route_30.object.don",
      "crystal.route_30.object.battle_youngster",
      "crystal.route_30.object.battle_mon_1",
      "crystal.route_30.object.battle_mon_2",
      "crystal.route_30.object.fruit_tree_1",
      "crystal.route_30.object.fruit_tree_2",
      "crystal.route_30.object.cooltrainer",
      "crystal.route_30.object.antidote",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.route_30.callback.objects"] = callback,
    },
    scenes = {},
    coordEvents = {},
    bgEvents = {
      ["crystal.route_30.bg.sign"] =
        Helpers.text("crystal.text.route_30.sign"),
      ["crystal.route_30.bg.mr_pokemon_directions"] =
        Helpers.text("crystal.text.route_30.directions_sign"),
      ["crystal.route_30.bg.mr_pokemon_house"] =
        Helpers.text("crystal.text.route_30.mr_pokemon_sign"),
      ["crystal.route_30.bg.trainer_tips"] =
        Helpers.text("crystal.text.route_30.trainer_tips"),
      ["crystal.route_30.bg.hidden_potion"] = Helpers.item(
        nil,
        "crystal.route_30.got_hidden_potion",
        "crystal.item.potion"
      ),
    },
    objects = {
      ["crystal.route_30.object.youngster"] = youngster,
      ["crystal.route_30.object.joey"] = Helpers.trainer(
        "crystal.trainer.22.001", 1449,
        "crystal.text.route_30.joey_after"),
      ["crystal.route_30.object.mikey"] = Helpers.trainer(
        "crystal.trainer.22.002", 1450,
        "crystal.text.route_30.mikey_after"),
      ["crystal.route_30.object.don"] = Helpers.trainer(
        "crystal.trainer.36.001", 1336,
        "crystal.text.route_30.don_after"),
      ["crystal.route_30.object.battle_youngster"] =
        Helpers.text("crystal.text.route_30.big_battle"),
      ["crystal.route_30.object.battle_mon_1"] =
        Helpers.text("crystal.text.route_30.battle_mon"),
      ["crystal.route_30.object.battle_mon_2"] =
        Helpers.text("crystal.text.route_30.battle_mon"),
      ["crystal.route_30.object.fruit_tree_1"] =
        Helpers.fruit("crystal.route_30.picked_fruit_1"),
      ["crystal.route_30.object.fruit_tree_2"] =
        Helpers.fruit("crystal.route_30.picked_fruit_2"),
      ["crystal.route_30.object.cooltrainer"] =
        Helpers.text("crystal.text.route_30.cooltrainer"),
      ["crystal.route_30.object.antidote"] = Helpers.item(
        ANTIDOTE,
        "crystal.route_30.got_antidote",
        "crystal.item.antidote"
      ),
    },
  },
}
