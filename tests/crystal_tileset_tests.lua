return function(test, equal, truthy, raises)
  local CrystalTileset = require("src.import.CrystalTileset")
  local Json = require("src.core.Json")
  local Rom = require("src.import.Rom")

  local function fixture()
    local zero1024 = string.char(0xef, 0xff)
    local compressed = zero1024 .. zero1024 .. zero1024
      .. string.char(0xff)

    local metatiles = {}
    for id = 0, CrystalTileset.METATILE_COUNT - 1 do
      metatiles[#metatiles + 1] =
        string.rep(string.char(id % 224), 16)
    end

    local collision = {}
    for id = 0, CrystalTileset.METATILE_COUNT - 1 do
      collision[#collision + 1] = string.char(
        id % 256,
        (id + 1) % 256,
        (id + 2) % 256,
        (id + 3) % 256
      )
    end

    local paletteMap = string.rep(string.char(0x21), 48)
      .. string.rep(string.char(0xff), 16)
      .. string.rep(string.char(0x98), 48)
    local palettes = string.char(0x1f, 0x00)
      .. string.rep("\0", CrystalTileset.BASE_PALETTE_SIZE - 2)

    local offsets = {}
    local parts = {}
    local position = 0
    local function add(name, data)
      offsets[name] = position
      parts[#parts + 1] = data
      position = position + #data
    end

    add("TilesetJohtoGFX", compressed)
    add("TilesetJohtoMeta", table.concat(metatiles))
    add("TilesetJohtoColl", table.concat(collision))
    add("TilesetIcePathGFX", "")
    add("TilesetJohtoPalMap", paletteMap)
    add("TilesetJohtoModernPalMap", "")
    add("TilesetBGPalette", palettes)
    add("MapObjectPals", "")

    local symbols = {}
    for name, offset in pairs(offsets) do
      symbols[name] = { offset = offset }
    end
    return table.concat(parts), { symbols = symbols }
  end

  test("CrystalTileset extracts normalized Johto data", function()
    local data, profile = fixture()
    local result = CrystalTileset.extractJohto(Rom.new(data), profile)

    equal(result.schema, 1)
    equal(result.id, "johto")
    equal(result.graphics.tileCount, 192)
    equal(#result.graphics.tiles, 192)
    equal(result.graphics.consumedBytes, 7)
    equal(#result.tileSlots, 224)
    equal(result.tileSlots[1].paletteId, 1)
    equal(result.tileSlots[2].paletteId, 2)
    equal(result.tileSlots[1].vramBank, 0)
    equal(result.tileSlots[97].vramBank, 1)
    truthy(result.tileSlots[97].graphicIndex == Json.null)
    equal(result.tileSlots[129].graphicIndex, 96)
    equal(result.tileSlots[129].runtimeTileId, 0)

    equal(result.metatiles.count, 128)
    equal(#result.metatiles.records[1].tileIds, 16)
    equal(result.metatiles.records[2].tileIds[1], 1)
    equal(result.collision.records[1].topLeft, 0)
    equal(result.collision.records[1].bottomRight, 3)

    local firstColor =
      result.palettes.timeOfDay.morning[1].colors[1]
    equal(firstColor.bgr15, 0x001f)
    equal(firstColor.rgb5[1], 31)
    equal(firstColor.rgb8[1], 255)
    equal(#result.palettes.overworldWater, 2)
    truthy(#Json.encode(result) > 0)
  end)

  test("CrystalTileset validates table boundaries", function()
    local data, profile = fixture()
    profile.symbols.TilesetJohtoColl.offset =
      profile.symbols.TilesetJohtoColl.offset - 1
    raises(function()
      CrystalTileset.extractJohto(Rom.new(data), profile)
    end, "metatile length")
  end)

  test("CrystalTileset rejects invalid bank and tile metadata", function()
    local data, profile = fixture()
    local paletteOffset = profile.symbols.TilesetJohtoPalMap.offset
    local wrongBank = data:sub(1, paletteOffset)
      .. string.char(0x29)
      .. data:sub(paletteOffset + 2)
    raises(function()
      CrystalTileset.extractJohto(Rom.new(wrongBank), profile)
    end, "wrong VRAM bank")

    local metatileOffset = profile.symbols.TilesetJohtoMeta.offset
    local badTile = data:sub(1, metatileOffset)
      .. string.char(224)
      .. data:sub(metatileOffset + 2)
    raises(function()
      CrystalTileset.extractJohto(Rom.new(badTile), profile)
    end, "unavailable tile")
  end)
end
