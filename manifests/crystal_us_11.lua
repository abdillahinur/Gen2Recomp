local generatedSymbols = require("manifests.crystal_us_11_symbols")
local battle = require("manifests.crystal_battle")
local text = require("manifests.crystal_text")
local world = require("manifests.crystal_world")

return {
  id = "crystal_us_11",
  family = "crystal",
  displayName = "Pokemon Crystal (English) v1.1",
  status = "supported",
  sha1 = "f2f52230b536214ef7c9924f483392993e226cfb",
  expectedSize = 2 * 1024 * 1024,
  -- Header values follow pret/pokecrystal's pinned RGBFIXFLAGS. Field meanings
  -- and checksum rules follow Pan Docs' cartridge-header specification.
  expectedHeader = {
    title = "PM_CRYSTAL",
    manufacturerCode = "BYTE",
    cgbFlag = 0xc0,
    newLicenseeCode = "01",
    sgbFlag = 0x00,
    cartridgeType = 0x10,
    romSizeCode = 0x06,
    ramSizeCode = 0x03,
    destinationCode = 0x01,
    oldLicenseeCode = 0x33,
    version = 0x01,
    -- Store only the fingerprint of the standard boot-logo header bytes.
    logoSha1 = "0745fdef34132d1b3d488cfbdf0379a39fd54b4c",
  },
  cacheSchema = 2,
  features = {
    color = true,
    animatedFrontSprites = true,
    femalePlayer = true,
    battleTower = true,
    crystalStory = true,
    realTimeClock = true,
  },
  reference = generatedSymbols.source,
  symbols = generatedSymbols.symbols,
  schemas = {
    font = 1,
    charmap = 1,
    species = 1,
    battle = 1,
    tileset = 1,
    text = 1,
    world = 1,
    encounters = 1,
  },
  battle = battle,
  text = text,
  world = world,
}
