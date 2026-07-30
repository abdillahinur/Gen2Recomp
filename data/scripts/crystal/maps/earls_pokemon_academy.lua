local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.earls_pokemon_academy",
  prefix = "crystal.earls_academy",
  mapId = "10:8",
  path = "maps/EarlsPokemonAcademy.asm",
  labels = {
    "EarlsPokemonAcademy_MapScripts",
    "AcademyEarl",
    "AcademyBlackboard",
    "AcademyNotebook",
  },
  notes = "Used for academy NPCs, bookshelves, blackboard, and notebook interactions.",
  bgEvents = {
    "crystal.text.common.difficult_bookshelf",
    "crystal.text.common.difficult_bookshelf",
    "crystal.text.earls_academy.blackboard",
    "crystal.text.earls_academy.blackboard",
  },
  objects = {
    "crystal.text.earls_academy.earl",
    "crystal.text.earls_academy.youngster_notes",
    "crystal.text.earls_academy.gameboy_kid_left",
    "crystal.text.earls_academy.gameboy_kid_right",
    "crystal.text.earls_academy.youngster_berry",
    "crystal.text.earls_academy.notebook",
  },
})
