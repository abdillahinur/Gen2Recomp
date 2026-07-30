local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.cherrygrove_gym_speech_house",
  prefix = "crystal.cherrygrove_gym_house",
  mapId = "26:6",
  path = "maps/CherrygroveGymSpeechHouse.asm",
  labels = {
    "CherrygroveGymSpeechHouse_MapScripts",
    "CherrygroveGymSpeechHousePokefanMScript",
    "CherrygroveGymSpeechHouseBugCatcherScript",
  },
  notes = "Used for house NPC and bookshelf interactions.",
  bgEvents = {
    "crystal.text.common.difficult_bookshelf",
    "crystal.text.common.difficult_bookshelf",
  },
  objects = {
    "crystal.text.cherrygrove_gym_house.pokefan",
    "crystal.text.cherrygrove_gym_house.bug_catcher",
  },
})
