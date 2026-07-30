local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local POTION = "crystal.route_31.actor.potion"
local POKE_BALL = "crystal.route_31.actor.poke_ball"

local function callback()
  if not Commands.hasFlag("crystal.story.talked_to_mom_after_egg") then
    Commands.setFlag("crystal.phone.mom_worried_call_pending")
  end
  if Commands.hasFlag("crystal.route_31.got_potion") then
    Commands.hideObject(POTION)
  end
  if Commands.hasFlag("crystal.route_31.got_poke_ball") then
    Commands.hideObject(POKE_BALL)
  end
end

return {
  schema = 1,
  id = "crystal.maps.route_31",
  game = "crystal",
  kind = "map",
  maps = { "26:2" },
  actors = {
    { id = POTION, mapId = "26:2", objectId = 6 },
    { id = POKE_BALL, mapId = "26:2", objectId = 7 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/Route31.asm",
      {
        "Route31_MapScripts",
        "Route31CheckMomCallCallback",
        "TrainerBugCatcherWade1",
        "Route31MailRecipientScript",
      },
      "Used for the worried-call gate, route trainer and NPC state, fruit, items, and signs."
    ),
  },
  coverage = {
    callbacks = { "crystal.route_31.callback.new_map" },
    scenes = {},
    coordEvents = {},
    bgEvents = {
      "crystal.route_31.bg.route_sign",
      "crystal.route_31.bg.dark_cave_sign",
    },
    objects = {
      "crystal.route_31.object.mail_recipient",
      "crystal.route_31.object.youngster",
      "crystal.route_31.object.wade",
      "crystal.route_31.object.cooltrainer",
      "crystal.route_31.object.fruit_tree",
      "crystal.route_31.object.potion",
      "crystal.route_31.object.poke_ball",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.route_31.callback.new_map"] = callback,
    },
    scenes = {},
    coordEvents = {},
    bgEvents = {
      ["crystal.route_31.bg.route_sign"] =
        Helpers.text("crystal.text.route_31.sign"),
      ["crystal.route_31.bg.dark_cave_sign"] =
        Helpers.text("crystal.text.route_31.dark_cave_sign"),
    },
    objects = {
      ["crystal.route_31.object.mail_recipient"] =
        Helpers.text("crystal.text.route_31.mail_recipient"),
      ["crystal.route_31.object.youngster"] =
        Helpers.text("crystal.text.route_31.youngster"),
      ["crystal.route_31.object.wade"] = Helpers.trainer(
        "crystal.trainer.36.004", 1339,
        "crystal.text.route_31.wade_after"),
      ["crystal.route_31.object.cooltrainer"] =
        Helpers.text("crystal.text.route_31.cooltrainer"),
      ["crystal.route_31.object.fruit_tree"] =
        Helpers.fruit("crystal.route_31.picked_fruit"),
      ["crystal.route_31.object.potion"] = Helpers.item(
        POTION,
        "crystal.route_31.got_potion",
        "crystal.item.potion"
      ),
      ["crystal.route_31.object.poke_ball"] = Helpers.item(
        POKE_BALL,
        "crystal.route_31.got_poke_ball",
        "crystal.item.poke_ball"
      ),
    },
  },
}
