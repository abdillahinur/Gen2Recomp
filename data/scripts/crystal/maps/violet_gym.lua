local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local FALKNER = "crystal.violet_gym.actor.falkner"
local LEADER = "crystal.trainer.01.001"

local function falkner()
  Commands.face(FALKNER, "down")
  if Commands.hasFlag("crystal.badge.zephyr") then
    if not Commands.hasFlag("crystal.violet_gym.got_tm31") then
      Commands.giveItem("crystal.item.tm31", 1)
      Commands.setFlag("crystal.violet_gym.got_tm31")
      Commands.text("crystal.text.violet_gym.tm31")
    else
      Commands.text("crystal.text.violet_gym.after")
    end
    return
  end
  Commands.text("crystal.text.violet_gym.falkner_intro")
  local result = Commands.battle("trainer", LEADER, {
    canLose = true,
    aiProfileId = "battle.ai.smart",
  })
  if not result.won then return end
  Commands.text("crystal.text.violet_gym.falkner_win")
  Commands.setFlag("crystal.story.beat_falkner")
  Commands.setFlag("crystal.badge.zephyr")
  Commands.setFlag("crystal.trainer.defeated.f1019")
  Commands.setFlag("crystal.trainer.defeated.f1020")
  Commands.playSfx("crystal.sfx.get_badge")
  Commands.text("crystal.text.violet_gym.got_zephyr_badge")
  Commands.text("crystal.text.violet_gym.zephyr_badge")
  Commands.giveItem("crystal.item.tm31", 1)
  Commands.setFlag("crystal.violet_gym.got_tm31")
  Commands.text("crystal.text.violet_gym.tm31")
end

local function guide()
  Commands.text(Commands.hasFlag("crystal.badge.zephyr")
    and "crystal.text.violet_gym.guide_after"
    or "crystal.text.violet_gym.guide_before")
end

local function statue()
  Commands.text(Commands.hasFlag("crystal.badge.zephyr")
    and "crystal.text.violet_gym.statue_champion"
    or "crystal.text.violet_gym.statue")
end

return {
  schema = 1,
  id = "crystal.maps.violet_gym",
  game = "crystal",
  kind = "map",
  maps = { "10:7" },
  actors = {
    { id = FALKNER, mapId = "10:7", objectId = 1 },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/VioletGym.asm",
      {
        "VioletGymFalknerScript",
        "TrainerBirdKeeperRod",
        "TrainerBirdKeeperAbe",
        "VioletGymGuideScript",
        "VioletGymStatue",
      },
      "Used for leader challenge, Gym trainers, badge/TM rewards, guide, and statue behavior."
    ),
  },
  coverage = {
    callbacks = {},
    scenes = {},
    coordEvents = {},
    bgEvents = {
      "crystal.violet_gym.bg.statue_left",
      "crystal.violet_gym.bg.statue_right",
    },
    objects = {
      "crystal.violet_gym.object.falkner",
      "crystal.violet_gym.object.rod",
      "crystal.violet_gym.object.abe",
      "crystal.violet_gym.object.guide",
    },
  },
  behavior = {
    callbacks = {},
    scenes = {},
    coordEvents = {},
    bgEvents = {
      ["crystal.violet_gym.bg.statue_left"] = statue,
      ["crystal.violet_gym.bg.statue_right"] = statue,
    },
    objects = {
      ["crystal.violet_gym.object.falkner"] = falkner,
      ["crystal.violet_gym.object.rod"] = Helpers.trainer(
        "crystal.trainer.24.001",
        1019,
        "crystal.text.violet_gym.rod_seen",
        "crystal.text.violet_gym.rod_after"
      ),
      ["crystal.violet_gym.object.abe"] = Helpers.trainer(
        "crystal.trainer.24.002",
        1020,
        "crystal.text.violet_gym.abe_seen",
        "crystal.text.violet_gym.abe_after"
      ),
      ["crystal.violet_gym.object.guide"] = guide,
    },
  },
}
