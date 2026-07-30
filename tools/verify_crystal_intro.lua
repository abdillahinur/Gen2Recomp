package.path = "./?.lua;./?/init.lua;" .. package.path

local CrystalIntroData = require("src.import.CrystalIntroData")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

local path = assert(arg[1], "usage: verify_crystal_intro.lua <rom-path>")
local file = assert(io.open(path, "rb"))
local data = file:read("*a")
file:close()

local identity = RomIdentifier.inspect(data)
assert(identity.accepted, table.concat(identity.errors or {}, "; "))
local intro = CrystalIntroData.extract(Rom.new(data), identity.profile)

assert(intro.schema == 1)
assert(#intro.clock.background == 64)
assert(#intro.clock.up == 64)
assert(#intro.clock.down == 64)
assert(#intro.pictures.professor.tiles == 49)
assert(#intro.pictures.wooper.tiles
  == intro.pictures.wooper.widthTiles
    * intro.pictures.wooper.heightTiles)
assert(#intro.pictures.male.tiles == 49)
assert(#intro.pictures.female.tiles == 49)
assert(#intro.pictures.shrink1.tiles == 49)
assert(#intro.pictures.shrink2.tiles == 49)
assert(#intro.pictures.maleIcon.tiles == 4)
assert(#intro.pictures.femaleIcon.tiles == 4)

print("Crystal intro assets verified for " .. identity.profile.id)
print("Clock tiles: 3; pictures: 8; all data decoded from supplied ROM")
