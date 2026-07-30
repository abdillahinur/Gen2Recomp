local CgbPalette = require("src.import.CgbPalette")
local CrystalLz = require("src.import.CrystalLz")
local TileDecoder = require("src.import.TileDecoder")

local CrystalIntroData = {}

local function symbol(profile, name)
  local value = profile.symbols and profile.symbols[name]
  if type(value) ~= "table" or type(value.offset) ~= "number" then
    error("Crystal intro profile is missing symbol " .. name, 3)
  end
  return value
end

local function paletteFromColors(colors)
  return { colors = colors }
end

local function color(rom, offset)
  return CgbPalette.decodeColorAt(rom:readString(offset, 2))
end

local function rowsFromColumns(tiles, width, height)
  local result = {}
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      result[y * width + x + 1] = tiles[x * height + y + 1]
    end
  end
  return result
end

local function trainerPalette(rom, profile, classIndex)
  local offset = symbol(profile, "TrainerPalettes").offset + classIndex * 4
  return paletteFromColors({
    CgbPalette.decodeColor(0xff, 0x7f),
    color(rom, offset),
    color(rom, offset + 2),
    CgbPalette.decodeColor(0x00, 0x00),
  })
end

local function pokemonPalette(rom, profile, species)
  local offset = symbol(profile, "PokemonPalettes").offset + species * 8
  return paletteFromColors({
    CgbPalette.decodeColor(0xff, 0x7f),
    color(rom, offset),
    color(rom, offset + 2),
    CgbPalette.decodeColor(0x00, 0x00),
  })
end

local function uncompressedPicture(rom, profile, name, width, height, palette)
  local byteLength = width * height * 16
  return {
    widthTiles = width,
    heightTiles = height,
    tiles = rowsFromColumns(TileDecoder.decode2bpp(
      rom:readString(symbol(profile, name).offset, byteLength)
    ), width, height),
    palette = palette,
  }
end

local function compressedPicture(
    rom, profile, name, width, height, palette)
  local offset = symbol(profile, name).offset
  local bankRemaining = 0x4000 - (offset % 0x4000)
  local decoded = CrystalLz.decompress(
    rom:readString(offset, bankRemaining),
    { maxOutputSize = 128 * 16 }
  )
  local expected = width * height * 16
  if #decoded < expected then
    error(("Crystal intro %s decoded to %d bytes; expected at least %d")
      :format(name, #decoded, expected), 2)
  end
  return {
    widthTiles = width,
    heightTiles = height,
    tiles = rowsFromColumns(
      TileDecoder.decode2bpp(decoded:sub(1, expected)),
      width,
      height
    ),
    palette = palette,
  }
end

local function playerIcon(rom, profile, name, palette)
  local decoded = TileDecoder.decode2bpp(
    rom:readString(symbol(profile, name).offset, 12 * 16)
  )
  return {
    widthTiles = 2,
    heightTiles = 2,
    tiles = { decoded[1], decoded[2], decoded[3], decoded[4] },
    palette = palette,
  }
end

local function wooperDimensions(rom, profile)
  local species = 194
  local record = symbol(profile, "BaseData").offset + (species - 1) * 32
  local dimensions = rom:readByte(record + 17)
  return math.floor(dimensions / 16), dimensions % 16
end

function CrystalIntroData.extract(rom, profile)
  local malePalette = trainerPalette(rom, profile, 0)
  local femalePalette = trainerPalette(rom, profile, 1)
  local professorPalette = trainerPalette(rom, profile, 10)
  local wooperWidth, wooperHeight = wooperDimensions(rom, profile)
  if wooperWidth < 1 or wooperHeight < 1
      or wooperWidth > 7 or wooperHeight > 7 then
    error("Crystal intro Wooper dimensions are invalid", 2)
  end

  local function clockTile(name)
    return TileDecoder.decode1bpp(
      rom:readString(symbol(profile, name).offset, 8)
    )[1]
  end

  return {
    schema = 1,
    clock = {
      background = clockTile("TimeSetBackgroundGFX"),
      up = clockTile("TimeSetUpArrowGFX"),
      down = clockTile("TimeSetDownArrowGFX"),
    },
    pictures = {
      professor = compressedPicture(
        rom, profile, "PokemonProfPic", 7, 7, professorPalette),
      wooper = compressedPicture(
        rom, profile, "WooperFrontpic",
        wooperWidth, wooperHeight,
        pokemonPalette(rom, profile, 194)),
      male = uncompressedPicture(
        rom, profile, "ChrisPic", 7, 7, malePalette),
      female = uncompressedPicture(
        rom, profile, "KrisPic", 7, 7, femalePalette),
      shrink1 = compressedPicture(
        rom, profile, "Shrink1Pic", 7, 7, malePalette),
      shrink2 = compressedPicture(
        rom, profile, "Shrink2Pic", 7, 7, malePalette),
      maleIcon = playerIcon(
        rom, profile, "ChrisSpriteGFX", malePalette),
      femaleIcon = playerIcon(
        rom, profile, "KrisSpriteGFX", femalePalette),
    },
  }
end

return CrystalIntroData
