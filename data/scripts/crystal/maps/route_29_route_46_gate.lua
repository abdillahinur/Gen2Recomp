local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.route_29_route_46_gate",
  prefix = "crystal.route_29_gate",
  mapId = "24:13",
  path = "maps/Route29Route46Gate.asm",
  labels = {
    "Route29Route46Gate_MapScripts",
    "Route29Route46GateOfficerScript",
    "Route29Route46GateYoungsterScript",
  },
  notes = "Used for both gate NPC interactions.",
  objects = {
    "crystal.text.route_29_gate.officer",
    "crystal.text.route_29_gate.youngster",
  },
})
