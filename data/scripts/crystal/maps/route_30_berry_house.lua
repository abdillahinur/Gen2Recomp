local Commands = require("src.script.Commands")
local StaticMap = require("data.scripts.crystal.StaticMap")

local function berryMan()
  if not Commands.hasFlag("crystal.route_30.berry_man_gift") then
    Commands.text("crystal.text.route_30_berry_house.gift")
    Commands.giveItem("crystal.item.berry", 1)
    Commands.setFlag("crystal.route_30.berry_man_gift")
  else
    Commands.text("crystal.text.route_30_berry_house.after")
  end
end

return StaticMap.define({
  id = "crystal.maps.route_30_berry_house",
  prefix = "crystal.route_30_berry_house",
  mapId = "26:9",
  path = "maps/Route30BerryHouse.asm",
  labels = {
    "Route30BerryHouse_MapScripts",
    "Route30BerryHousePokefanMScript",
  },
  notes = "Used for the one-time Berry handoff and bookshelf interactions.",
  bgEvents = {
    "crystal.text.common.difficult_bookshelf",
    "crystal.text.common.difficult_bookshelf",
  },
  objects = { berryMan },
})
