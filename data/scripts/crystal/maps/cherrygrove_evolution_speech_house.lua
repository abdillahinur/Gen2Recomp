local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.cherrygrove_evolution_speech_house",
  prefix = "crystal.cherrygrove_evolution_house",
  mapId = "26:8",
  path = "maps/CherrygroveEvolutionSpeechHouse.asm",
  labels = {
    "CherrygroveEvolutionSpeechHouse_MapScripts",
    "CherrygroveEvolutionSpeechHouseLassScript",
    "CherrygroveEvolutionSpeechHouseYoungsterScript",
  },
  notes = "Used for evolution-house NPC and bookshelf interactions.",
  bgEvents = {
    "crystal.text.common.difficult_bookshelf",
    "crystal.text.common.difficult_bookshelf",
  },
  objects = {
    "crystal.text.cherrygrove_evolution_house.lass",
    "crystal.text.cherrygrove_evolution_house.youngster",
  },
})
