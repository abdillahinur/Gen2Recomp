local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local PLAYER = "common.actor.player"
local GREAT_BALL = "crystal.route_32.actor.great_ball"
local FRIEDA = "crystal.route_32.actor.frieda"
local REPEL = "crystal.route_32.actor.repel"
local YES = "common.choice.yes"

local function callback()
  if Commands.getVariable("clock.weekday", -1) == 5 then
    Commands.showObject(FRIEDA)
  else
    Commands.hideObject(FRIEDA)
  end
  if Commands.hasFlag("crystal.route_32.got_great_ball") then
    Commands.hideObject(GREAT_BALL)
  end
  if Commands.hasFlag("crystal.route_32.got_repel") then
    Commands.hideObject(REPEL)
  end
end

local function badgeGuard()
  if Commands.hasFlag("crystal.badge.zephyr") then
    Commands.text("crystal.text.route_32.guard_after_badge")
    return
  end
  Commands.text("crystal.text.route_32.guard_before_badge")
  Commands.move(PLAYER, { "up", "up" })
  Commands.face(PLAYER, "down")
end

local function slowpokeTail()
  Commands.text("crystal.text.route_32.slowpoke_tail_offer")
  local answer = Commands.choice("crystal.choice.route_32.slowpoke_tail", {
    { id = YES, textId = "common.text.yes" },
    { id = "common.choice.no", textId = "common.text.no" },
  })
  Commands.text(answer == YES
    and "crystal.text.route_32.slowpoke_tail_too_expensive"
    or "crystal.text.route_32.slowpoke_tail_refused")
end

local function roarGift()
  if not Commands.hasFlag("crystal.route_32.got_tm_roar") then
    Commands.text("crystal.text.route_32.roar_intro")
    Commands.giveItem("crystal.item.tm05", 1)
    Commands.setFlag("crystal.route_32.got_tm_roar")
  end
  Commands.text("crystal.text.route_32.roar_outro")
end

local function frieda()
  if not Commands.hasFlag("crystal.route_32.got_poison_barb") then
    Commands.text("crystal.text.route_32.frieda_intro")
    Commands.giveItem("crystal.item.poison_barb", 1)
    Commands.setFlag("crystal.route_32.got_poison_barb")
  end
  Commands.text("crystal.text.route_32.frieda_after")
end

return {
  schema = 1,
  id = "crystal.maps.route_32",
  game = "crystal",
  kind = "map",
  maps = { "10:1" },
  automaticCoordEvents = true,
  actors = {
    { id = GREAT_BALL, mapId = "10:1", objectId = 11 },
    { id = FRIEDA, mapId = "10:1", objectId = 13 },
    { id = REPEL, mapId = "10:1", objectId = 14 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/Route32.asm",
      {
        "Route32_MapScripts",
        "Route32FriedaCallback",
        "Route32CooltrainerMStopsYouScene",
        "Route32WannaBuyASlowpokeTailScript",
        "Route32RoarTMGuyScript",
      },
      "Used for the first-badge route guard, trainers, salesman, gifts, weekday NPC, items, and signs."
    ),
  },
  coverage = {
    callbacks = { "crystal.route_32.callback.objects" },
    scenes = {
      "crystal.route_32.scene.badge_guard",
      "crystal.route_32.scene.slowpoke_tail",
    },
    coordEvents = {
      "crystal.route_32.coord.badge_guard",
      "crystal.route_32.coord.slowpoke_tail",
    },
    bgEvents = {
      "crystal.route_32.bg.route_sign",
      "crystal.route_32.bg.ruins_sign",
      "crystal.route_32.bg.union_cave_sign",
      "crystal.route_32.bg.pokecenter_sign",
      "crystal.route_32.bg.hidden_great_ball",
      "crystal.route_32.bg.hidden_super_potion",
    },
    objects = {
      "crystal.route_32.object.justin",
      "crystal.route_32.object.ralph",
      "crystal.route_32.object.henry",
      "crystal.route_32.object.albert",
      "crystal.route_32.object.gordon",
      "crystal.route_32.object.roland",
      "crystal.route_32.object.liz",
      "crystal.route_32.object.badge_guard",
      "crystal.route_32.object.peter",
      "crystal.route_32.object.slowpoke_tail",
      "crystal.route_32.object.great_ball",
      "crystal.route_32.object.roar_gift",
      "crystal.route_32.object.frieda",
      "crystal.route_32.object.repel",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.route_32.callback.objects"] = callback,
    },
    scenes = {
      ["crystal.route_32.scene.badge_guard"] = badgeGuard,
      ["crystal.route_32.scene.slowpoke_tail"] = slowpokeTail,
    },
    coordEvents = {
      ["crystal.route_32.coord.badge_guard"] = badgeGuard,
      ["crystal.route_32.coord.slowpoke_tail"] = slowpokeTail,
    },
    bgEvents = {
      ["crystal.route_32.bg.route_sign"] =
        Helpers.text("crystal.text.route_32.route_sign"),
      ["crystal.route_32.bg.ruins_sign"] =
        Helpers.text("crystal.text.route_32.ruins_sign"),
      ["crystal.route_32.bg.union_cave_sign"] =
        Helpers.text("crystal.text.route_32.union_cave_sign"),
      ["crystal.route_32.bg.pokecenter_sign"] =
        Helpers.text("crystal.text.common.pokecenter_sign"),
      ["crystal.route_32.bg.hidden_great_ball"] = Helpers.item(
        nil, "crystal.route_32.got_hidden_great_ball",
        "crystal.item.great_ball"),
      ["crystal.route_32.bg.hidden_super_potion"] = Helpers.item(
        nil, "crystal.route_32.got_hidden_super_potion",
        "crystal.item.super_potion"),
    },
    objects = {
      ["crystal.route_32.object.justin"] = Helpers.trainer(
        "crystal.trainer.37.001", 1102,
        "crystal.text.route_32.justin_after"),
      ["crystal.route_32.object.ralph"] = Helpers.trainer(
        "crystal.trainer.37.002", 1103,
        "crystal.text.route_32.ralph_after"),
      ["crystal.route_32.object.henry"] = Helpers.trainer(
        "crystal.trainer.37.005", 1106,
        "crystal.text.route_32.henry_after"),
      ["crystal.route_32.object.albert"] = Helpers.trainer(
        "crystal.trainer.22.003", 1451,
        "crystal.text.route_32.albert_after"),
      ["crystal.route_32.object.gordon"] = Helpers.trainer(
        "crystal.trainer.22.004", 1452,
        "crystal.text.route_32.gordon_after"),
      ["crystal.route_32.object.roland"] = Helpers.trainer(
        "crystal.trainer.54.001", 1050,
        "crystal.text.route_32.roland_after"),
      ["crystal.route_32.object.liz"] = Helpers.trainer(
        "crystal.trainer.53.001", 1150,
        "crystal.text.route_32.liz_after"),
      ["crystal.route_32.object.badge_guard"] = badgeGuard,
      ["crystal.route_32.object.peter"] = Helpers.trainer(
        "crystal.trainer.24.013", 1031,
        "crystal.text.route_32.peter_after"),
      ["crystal.route_32.object.slowpoke_tail"] = slowpokeTail,
      ["crystal.route_32.object.great_ball"] = Helpers.item(
        GREAT_BALL, "crystal.route_32.got_great_ball",
        "crystal.item.great_ball"),
      ["crystal.route_32.object.roar_gift"] = roarGift,
      ["crystal.route_32.object.frieda"] = frieda,
      ["crystal.route_32.object.repel"] = Helpers.item(
        REPEL, "crystal.route_32.got_repel", "crystal.item.repel"),
    },
  },
}
