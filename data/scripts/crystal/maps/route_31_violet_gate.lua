local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.route_31_violet_gate",
  prefix = "crystal.route_31_gate",
  mapId = "26:11",
  path = "maps/Route31VioletGate.asm",
  labels = {
    "Route31VioletGate_MapScripts",
    "Route31VioletGateOfficerScript",
    "Route31VioletGateCooltrainerFScript",
  },
  notes = "Used for both Violet gate NPC interactions.",
  objects = {
    "crystal.text.route_31_gate.officer",
    "crystal.text.route_31_gate.cooltrainer",
  },
})
