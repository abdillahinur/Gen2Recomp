local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.violet_kyles_house",
  prefix = "crystal.violet_kyle_house",
  mapId = "10:11",
  path = "maps/VioletKylesHouse.asm",
  labels = {
    "VioletKylesHouse_MapScripts",
    "VioletKylesHousePokefanMScript",
    "Kyle",
  },
  notes = "Used for Kyle's trade prompt boundary and the house NPC.",
  objects = {
    "crystal.text.violet_kyle_house.pokefan",
    "crystal.text.violet_kyle_house.kyle",
  },
})
