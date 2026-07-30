local Commands = require("src.script.Commands")
local Provenance = require("data.scripts.Provenance")

local PLAYER = "common.actor.player"
local ELM = "crystal.elms_lab.actor.elm"
local AIDE = "crystal.elms_lab.actor.aide"

local YES = "common.choice.yes"
local BALL_ACTORS = {
  cyndaquil = "crystal.elms_lab.actor.cyndaquil_ball",
  totodile = "crystal.elms_lab.actor.totodile_ball",
  chikorita = "crystal.elms_lab.actor.chikorita_ball",
}

local function objectsCallback()
  local scene = Commands.getScene("crystal.map.elms_lab")
  if not scene or scene == "crystal.scene.elms_lab.meet_elm" then
    Commands.placeObject(ELM, 3, 4, "down")
  end
end

local function meetElm()
  Commands.move(PLAYER, {
    "up", "up", "up", "up", "up", "up", "up",
  })
  Commands.emote(ELM, "common.emote.shock", 15 / 60)
  Commands.face(ELM, "right")
  Commands.text("crystal.text.elms_lab.elm_intro")

  local accepted = false
  while not accepted do
    accepted = Commands.choice("crystal.choice.elms_lab.help_elm", {
      { id = YES, textId = "common.text.yes" },
      { id = "common.choice.no", textId = "common.text.no" },
    }) == YES
    if not accepted then
      Commands.text("crystal.text.elms_lab.elm_refused")
    end
  end

  Commands.text("crystal.text.elms_lab.elm_accepted")
  Commands.text("crystal.text.elms_lab.research_ambitions")
  Commands.playSfx("crystal.sfx.glass_ting")
  Commands.pause(30 / 60)
  Commands.emote(ELM, "common.emote.shock", 10 / 60)
  Commands.face(ELM, "down")
  Commands.text("crystal.text.elms_lab.got_email")
  Commands.face(ELM, "right")
  Commands.text("crystal.text.elms_lab.mr_pokemon_mission")
  Commands.move(ELM, { "up" })
  Commands.face(PLAYER, "up")
  Commands.move(ELM, { "right", "right", "up" })
  Commands.face(ELM, "down")
  Commands.face(PLAYER, "right")
  Commands.text("crystal.text.elms_lab.choose_pokemon")
  Commands.setScene(
    "crystal.map.elms_lab",
    "crystal.scene.elms_lab.cant_leave"
  )
end

local function cannotLeave()
  Commands.face(ELM, "down")
  Commands.text("crystal.text.elms_lab.where_are_you_going")
  Commands.move(PLAYER, { "up" })
end

local function elmInteraction()
  Commands.face(ELM, "down")
  if Commands.hasFlag("crystal.story.got_starter") then
    Commands.text("crystal.text.elms_lab.elm_describes_mr_pokemon")
  else
    Commands.text("crystal.text.elms_lab.let_your_pokemon_battle")
  end
end

local function aideInteraction()
  Commands.face(AIDE, "down")
  Commands.text("crystal.text.elms_lab.aide_always_busy")
end

local function inspectStarter(species)
  if Commands.hasFlag("crystal.story.got_starter") then
    Commands.text("crystal.text.elms_lab.poke_ball")
    return nil
  end
  Commands.face(ELM, "down")
  Commands.playCry("crystal.species." .. species)
  local selected = Commands.choice(
    "crystal.choice.elms_lab.take_" .. species,
    {
      { id = YES, textId = "common.text.yes" },
      { id = "common.choice.no", textId = "common.text.no" },
    }
  )
  if selected ~= YES then
    Commands.text("crystal.text.elms_lab.did_not_choose_starter")
    return nil
  end

  Commands.hideObject(BALL_ACTORS[species])
  Commands.setFlag("crystal.story.got_" .. species .. "_from_elm")
  Commands.text("crystal.text.elms_lab.chose_starter")
  Commands.text("crystal.text.elms_lab.received_starter", {
    species = "crystal.species." .. species,
  })
  Commands.playSfx("crystal.sfx.caught_pokemon")
  Commands.givePokemon(
    "crystal.species." .. species,
    5,
    "crystal.item.berry"
  )

  local player = Commands.actorState(PLAYER)
  if species == "cyndaquil" then
    if player.facing ~= "right" then
      Commands.move(PLAYER, { "left", "up" })
    end
  elseif species == "totodile" then
    Commands.move(PLAYER, { "left", "left", "up" })
  else
    Commands.move(PLAYER, { "left", "left", "left", "up" })
  end

  Commands.face(PLAYER, "up")
  Commands.text("crystal.text.elms_lab.directions_to_mr_pokemon")
  Commands.registerPhoneContact("crystal.phone.professor_elm")
  Commands.text("crystal.text.elms_lab.got_elm_phone_number")
  Commands.playSfx("crystal.sfx.register_phone_number")
  Commands.face(ELM, "left")
  Commands.text("crystal.text.elms_lab.healing_machine_directions")
  Commands.face(ELM, "down")
  Commands.text("crystal.text.elms_lab.elm_is_counting_on_you")

  Commands.setFlag("crystal.story.got_starter")
  Commands.setFlag("crystal.story.rival_cherrygrove_active")
  Commands.setScene(
    "crystal.map.elms_lab",
    "crystal.scene.elms_lab.aide_gives_potion"
  )
  Commands.setScene(
    "crystal.map.new_bark",
    "crystal.scene.new_bark.noop"
  )
  return species
end

local function aideGivesPotion(extraStep)
  local movement = { "right", "right" }
  if extraStep then movement[#movement + 1] = "right" end
  Commands.move(AIDE, movement)
  Commands.face(PLAYER, "down")
  Commands.text("crystal.text.elms_lab.aide_gives_potion")
  Commands.giveItem("crystal.item.potion", 1)
  Commands.text("crystal.text.elms_lab.aide_always_busy")
  Commands.setScene(
    "crystal.map.elms_lab",
    "crystal.scene.elms_lab.noop"
  )
  local returnMovement = { "left", "left" }
  if extraStep then returnMovement[#returnMovement + 1] = "left" end
  Commands.move(AIDE, returnMovement)
  Commands.face(AIDE, "down")
end

local function aidePotionLeft()
  aideGivesPotion(false)
end

local function aidePotionRight()
  aideGivesPotion(true)
end

local function text(id)
  return function() Commands.text(id) end
end

local bg = {
  ["crystal.elms_lab.bg.healing_machine"] = function()
    if Commands.hasFlag("crystal.story.got_starter") then
      Commands.text("crystal.text.elms_lab.healing_machine_ready")
    else
      Commands.text("crystal.text.elms_lab.healing_machine_unknown")
    end
  end,
  ["crystal.elms_lab.bg.bookshelf_top_1"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.bookshelf_top_2"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.bookshelf_top_3"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.bookshelf_top_4"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.travel_tip_1"] =
    text("crystal.text.elms_lab.travel_tip_1"),
  ["crystal.elms_lab.bg.travel_tip_2"] =
    text("crystal.text.elms_lab.travel_tip_2"),
  ["crystal.elms_lab.bg.travel_tip_3"] =
    text("crystal.text.elms_lab.travel_tip_3"),
  ["crystal.elms_lab.bg.travel_tip_4"] =
    text("crystal.text.elms_lab.travel_tip_4"),
  ["crystal.elms_lab.bg.bookshelf_bottom_1"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.bookshelf_bottom_2"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.bookshelf_bottom_3"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.bookshelf_bottom_4"] =
    text("crystal.text.common.difficult_bookshelf"),
  ["crystal.elms_lab.bg.trashcan"] =
    text("crystal.text.elms_lab.trashcan"),
  ["crystal.elms_lab.bg.window"] = function()
    local id = Commands.hasFlag("crystal.story.elm_called_about_theft")
      and "crystal.text.elms_lab.window_break_in"
      or "crystal.text.elms_lab.window_normal"
    Commands.text(id)
  end,
  ["crystal.elms_lab.bg.pc"] = text("crystal.text.elms_lab.pc"),
}

return {
  schema = 1,
  id = "crystal.maps.elms_lab",
  game = "crystal",
  kind = "map",
  maps = { "24:5" },
  actors = {
    { id = ELM, mapId = "24:5", objectId = 1 },
    { id = AIDE, mapId = "24:5", objectId = 2 },
    {
      id = "crystal.elms_lab.actor.cyndaquil_ball",
      mapId = "24:5",
      objectId = 3,
    },
    {
      id = "crystal.elms_lab.actor.totodile_ball",
      mapId = "24:5",
      objectId = 4,
    },
    {
      id = "crystal.elms_lab.actor.chikorita_ball",
      mapId = "24:5",
      objectId = 5,
    },
    {
      id = "crystal.elms_lab.actor.officer",
      mapId = "24:5",
      objectId = 6,
    },
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/ElmsLab.asm",
      {
        "ElmsLab_MapScripts",
        "ElmsLabMoveElmCallback",
        "ElmsLabWalkUpToElmScript",
        "LabTryToLeaveScript",
        "ProfElmScript",
        "CyndaquilPokeBallScript",
        "TotodilePokeBallScript",
        "ChikoritaPokeBallScript",
        "ElmDirectionsScript",
        "AideScript_WalkPotion1",
        "AideScript_WalkPotion2",
        "AideScript_GivePotion",
        "ElmsAideScript",
      },
      "Used to reproduce the initial Elm meeting, exit guard, starter selection, phone registration, Potion handoff, lab actors, and background interactions."
    ),
  },
  coverage = {
    callbacks = { "crystal.elms_lab.callback.objects" },
    scenes = {
      "crystal.elms_lab.scene.meet_elm",
      "crystal.elms_lab.scene.cant_leave",
    },
    coordEvents = {
      "crystal.elms_lab.coord.cant_leave_left",
      "crystal.elms_lab.coord.cant_leave_right",
      "crystal.elms_lab.coord.aide_potion_left",
      "crystal.elms_lab.coord.aide_potion_right",
    },
    bgEvents = {
      "crystal.elms_lab.bg.healing_machine",
      "crystal.elms_lab.bg.bookshelf_top_1",
      "crystal.elms_lab.bg.bookshelf_top_2",
      "crystal.elms_lab.bg.bookshelf_top_3",
      "crystal.elms_lab.bg.bookshelf_top_4",
      "crystal.elms_lab.bg.travel_tip_1",
      "crystal.elms_lab.bg.travel_tip_2",
      "crystal.elms_lab.bg.travel_tip_3",
      "crystal.elms_lab.bg.travel_tip_4",
      "crystal.elms_lab.bg.bookshelf_bottom_1",
      "crystal.elms_lab.bg.bookshelf_bottom_2",
      "crystal.elms_lab.bg.bookshelf_bottom_3",
      "crystal.elms_lab.bg.bookshelf_bottom_4",
      "crystal.elms_lab.bg.trashcan",
      "crystal.elms_lab.bg.window",
      "crystal.elms_lab.bg.pc",
    },
    objects = {
      "crystal.elms_lab.object.elm",
      "crystal.elms_lab.object.aide",
      "crystal.elms_lab.object.cyndaquil_ball",
      "crystal.elms_lab.object.totodile_ball",
      "crystal.elms_lab.object.chikorita_ball",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.elms_lab.callback.objects"] = objectsCallback,
    },
    scenes = {
      ["crystal.elms_lab.scene.meet_elm"] = meetElm,
      ["crystal.elms_lab.scene.cant_leave"] = cannotLeave,
    },
    coordEvents = {
      ["crystal.elms_lab.coord.cant_leave_left"] = cannotLeave,
      ["crystal.elms_lab.coord.cant_leave_right"] = cannotLeave,
      ["crystal.elms_lab.coord.aide_potion_left"] = aidePotionLeft,
      ["crystal.elms_lab.coord.aide_potion_right"] = aidePotionRight,
    },
    bgEvents = bg,
    objects = {
      ["crystal.elms_lab.object.elm"] = elmInteraction,
      ["crystal.elms_lab.object.aide"] = aideInteraction,
      ["crystal.elms_lab.object.cyndaquil_ball"] =
        function() return inspectStarter("cyndaquil") end,
      ["crystal.elms_lab.object.totodile_ball"] =
        function() return inspectStarter("totodile") end,
      ["crystal.elms_lab.object.chikorita_ball"] =
        function() return inspectStarter("chikorita") end,
    },
  },
}
