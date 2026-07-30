local Commands = require("src.script.Commands")
local Helpers = require("data.scripts.crystal.MapHelpers")
local Provenance = require("data.scripts.Provenance")

local MR_POKEMON = "crystal.mr_pokemon.actor.mr_pokemon"
local OAK = "crystal.mr_pokemon.actor.oak"

local function callback()
  if Commands.hasFlag("crystal.story.got_pokedex") then
    Commands.hideObject(OAK)
  else
    Commands.showObject(OAK)
  end
end

local function meeting()
  if Commands.hasFlag("crystal.story.got_pokedex") then return end
  Commands.emote(MR_POKEMON, "common.emote.shock", 15 / 60)
  Commands.face(MR_POKEMON, "down")
  Commands.text("crystal.text.mr_pokemon.intro_1")
  Commands.text("crystal.text.mr_pokemon.intro_2")
  Commands.giveItem("crystal.item.mystery_egg", 1)
  Commands.setFlag("crystal.story.got_mystery_egg")
  Commands.text("crystal.text.mr_pokemon.got_egg")
  Commands.text("crystal.text.mr_pokemon.intro_3")
  Commands.face(MR_POKEMON, "right")
  Commands.text("crystal.text.mr_pokemon.intro_4")
  Commands.face(OAK, "left")
  Commands.text("crystal.text.mr_pokemon.intro_5")
  Commands.playMusic("crystal.music.prof_oak")
  Commands.text("crystal.text.mr_pokemon.oak_1")
  Commands.setFlag("crystal.story.got_pokedex")
  Commands.setFlag("crystal.feature.pokedex")
  Commands.text("crystal.text.mr_pokemon.got_pokedex")
  Commands.text("crystal.text.mr_pokemon.oak_2")
  Commands.hideObject(OAK)
  Commands.text("crystal.text.mr_pokemon.heal")
  Commands.text("crystal.text.mr_pokemon.depending_on_you")
  Commands.setFlag("crystal.story.elms_lab_robbed")
  Commands.setScene(
    "crystal.map.mr_pokemons_house",
    "crystal.scene.mr_pokemons_house.complete"
  )
  Commands.playMusic("crystal.music.route_30")
end

local function mrPokemon()
  Commands.face(MR_POKEMON, "down")
  Commands.text("crystal.text.mr_pokemon.depending_on_you")
end

return {
  schema = 1,
  id = "crystal.maps.mr_pokemons_house",
  game = "crystal",
  kind = "map",
  maps = { "26:10" },
  actors = {
    { id = MR_POKEMON, mapId = "26:10", objectId = 1 },
    { id = OAK, mapId = "26:10", objectId = 2 },
  },
  entryScenes = {
    ["26:10"] = "crystal.mr_pokemon.scene.meeting",
  },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/MrPokemonsHouse.asm",
      {
        "MrPokemonsHouse_MapScripts",
        "MrPokemonsHouseMrPokemonEventScript",
        "MrPokemonsHouse_MrPokemonScript",
        "MrPokemonsHouse_OakScript",
      },
      "Used for the Mystery Egg meeting, Oak's Pokedex handoff, follow-up state, and room interactions."
    ),
  },
  coverage = {
    callbacks = { "crystal.mr_pokemon.callback.objects" },
    scenes = { "crystal.mr_pokemon.scene.meeting" },
    coordEvents = {},
    bgEvents = {
      "crystal.mr_pokemon.bg.bookshelf_left",
      "crystal.mr_pokemon.bg.bookshelf_right",
      "crystal.mr_pokemon.bg.magazines_left",
      "crystal.mr_pokemon.bg.magazines_right",
      "crystal.mr_pokemon.bg.computer",
    },
    objects = {
      "crystal.mr_pokemon.object.mr_pokemon",
      "crystal.mr_pokemon.object.oak",
    },
  },
  behavior = {
    callbacks = {
      ["crystal.mr_pokemon.callback.objects"] = callback,
    },
    scenes = {
      ["crystal.mr_pokemon.scene.meeting"] = meeting,
    },
    coordEvents = {},
    bgEvents = {
      ["crystal.mr_pokemon.bg.bookshelf_left"] =
        Helpers.text("crystal.text.common.difficult_bookshelf"),
      ["crystal.mr_pokemon.bg.bookshelf_right"] =
        Helpers.text("crystal.text.common.difficult_bookshelf"),
      ["crystal.mr_pokemon.bg.magazines_left"] =
        Helpers.text("crystal.text.mr_pokemon.magazines"),
      ["crystal.mr_pokemon.bg.magazines_right"] =
        Helpers.text("crystal.text.mr_pokemon.magazines"),
      ["crystal.mr_pokemon.bg.computer"] =
        Helpers.text("crystal.text.mr_pokemon.computer"),
    },
    objects = {
      ["crystal.mr_pokemon.object.mr_pokemon"] = mrPokemon,
      ["crystal.mr_pokemon.object.oak"] = meeting,
    },
  },
}
