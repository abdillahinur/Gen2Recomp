local Commands = require("src.script.Commands")
local Provenance = require("data.scripts.Provenance")

local BOY = "crystal.profile.gender.boy"
local GIRL = "crystal.profile.gender.girl"

local function run()
  local genderChoice = Commands.choice(
    "crystal.choice.player_gender",
    {
      {
        id = BOY,
        textId = "crystal.text.player_gender.boy",
      },
      {
        id = GIRL,
        textId = "crystal.text.player_gender.girl",
      },
    }
  )
  local gender = genderChoice == GIRL and "female" or "male"
  Commands.setVariable("player.gender", gender)

  local clock = Commands.setupClock()
  Commands.setVariable("clock.hour", clock.hour)
  Commands.setVariable("clock.minute", clock.minute)
  Commands.playMusic("crystal.music.route_30")
  Commands.text("crystal.text.introduction.oak_1")
  Commands.text("crystal.text.introduction.oak_2")
  Commands.playCry("crystal.species.wooper")
  Commands.text("crystal.text.introduction.oak_3")
  Commands.text("crystal.text.introduction.oak_4")
  Commands.text("crystal.text.introduction.oak_5")
  Commands.text("crystal.text.introduction.oak_6")

  local name = Commands.selectName(gender)
  Commands.setVariable("player.name", name)
  Commands.text("crystal.text.introduction.oak_7", { player = name })

  Commands.setFlag("crystal.story.introduction_complete")
  Commands.setScene(
    "crystal.flow.introduction",
    "crystal.scene.introduction.complete"
  )
  return {
    gender = gender,
    name = name,
  }
end

return {
  schema = 1,
  id = "crystal.flows.introduction",
  game = "crystal",
  kind = "flow",
  maps = {},
  provenance = {
    Provenance.citation(
      "crystal",
      "engine/menus/intro_menu.asm",
      {
        "PlayerProfileSetup",
        "OakSpeech",
        "NamePlayer",
        "StorePlayerName",
      },
      "Used to reproduce profile setup, professor presentation, naming, and completion order."
    ),
    Provenance.citation(
      "crystal",
      "engine/menus/init_gender.asm",
      { "InitGender" },
      "Used to reproduce the two-option player-gender selection before the professor sequence."
    ),
    Provenance.citation(
      "crystal",
      "engine/rtc/timeset.asm",
      { "InitClock", "SetHour", "SetMinutes", "SetDayOfWeek" },
      "Used to place clock setup between profile selection and the professor presentation."
    ),
    Provenance.citation(
      "crystal",
      "engine/menus/naming_screen.asm",
      { "NamingScreen" },
      "Used to model custom-name entry as a native presentation service."
    ),
  },
  coverage = {
    callbacks = {},
    scenes = {
      "crystal.introduction.scene.gender",
      "crystal.introduction.scene.clock",
      "crystal.introduction.scene.professor",
      "crystal.introduction.scene.naming",
      "crystal.introduction.scene.complete",
    },
    coordEvents = {},
    bgEvents = {},
    objects = {},
  },
  behavior = {
    run = run,
  },
}
