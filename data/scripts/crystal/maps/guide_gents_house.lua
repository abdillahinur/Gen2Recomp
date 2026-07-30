local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.guide_gents_house",
  prefix = "crystal.guide_house",
  mapId = "26:7",
  path = "maps/GuideGentsHouse.asm",
  labels = {
    "GuideGentsHouse_MapScripts",
    "GuideGentsHouseGuideGent",
  },
  notes = "Used for the guide's follow-up and bookshelf interactions.",
  bgEvents = {
    "crystal.text.common.difficult_bookshelf",
    "crystal.text.common.difficult_bookshelf",
  },
  objects = { "crystal.text.guide_house.guide" },
})
