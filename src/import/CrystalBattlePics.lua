local CgbPalette = require("src.import.CgbPalette")
local CrystalLz = require("src.import.CrystalLz")
local Json = require("src.core.Json")
local TileDecoder = require("src.import.TileDecoder")

local CrystalBattlePics = {}

local SPECIES_COUNT = 251
local PICS_FIX = 0x36
local BACK_TILES = 6
local MAX_PIC_BYTES = 0x2000

local function symbol(profile, name)
  local value = profile.symbols and profile.symbols[name]
  if type(value) ~= "table" or type(value.offset) ~= "number" then
    error("Crystal battle pics profile is missing symbol " .. name, 3)
  end
  return value
end

local function paletteFromColors(colors)
  return { colors = colors }
end

local function color(rom, offset)
  return CgbPalette.decodeColorAt(rom:readString(offset, 2))
end

local function pokemonPalette(rom, profile, species, shiny)
  local offset = symbol(profile, "PokemonPalettes").offset + species * 8
  if shiny then offset = offset + 4 end
  return paletteFromColors({
    CgbPalette.decodeColor(0xff, 0x7f),
    color(rom, offset),
    color(rom, offset + 2),
    CgbPalette.decodeColor(0x00, 0x00),
  })
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

local function rowsFromColumns(tiles, width, height)
  local result = {}
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      result[y * width + x + 1] = tiles[x * height + y + 1]
    end
  end
  return result
end

function CrystalBattlePics.fixPicBank(stored)
  return stored + PICS_FIX
end

-- Crystal PadFrontpic left/top tile offsets inside the 7x7 enemy slot.
function CrystalBattlePics.frontPadOffset(widthTiles, heightTiles)
  if widthTiles >= 7 and heightTiles >= 7 then
    return 0, 0
  end
  if widthTiles == 6 then
    return 1, 1
  end
  if widthTiles == 5 then
    return 1, 2
  end
  return math.max(0, 7 - widthTiles), math.max(0, 7 - heightTiles)
end

local function readPicPointer(rom, tableOffset, index, which)
  local entry = tableOffset + (index - 1) * 6 + (which == "back" and 3 or 0)
  local storedBank = rom:readByte(entry)
  local address = rom:readWord(entry + 1)
  if storedBank == 0xff or address == 0xffff then
    return nil
  end
  local bank = CrystalBattlePics.fixPicBank(storedBank)
  if bank < 1 or bank > 0x7f or address < 0x4000 or address > 0x7fff then
    return nil
  end
  return rom:offset(bank, address, 1)
end

local function decompressPicture(rom, offset, width, height)
  local bankRemaining = 0x4000 - (offset % 0x4000)
  local decoded = CrystalLz.decompress(
    rom:readString(offset, bankRemaining),
    { maxOutputSize = MAX_PIC_BYTES }
  )
  local expected = width * height * 16
  if #decoded < expected then
    error(("Crystal battle pic at 0x%X decoded to %d bytes; expected >= %d")
      :format(offset, #decoded, expected), 3)
  end
  return {
    widthTiles = width,
    heightTiles = height,
    tiles = rowsFromColumns(
      TileDecoder.decode2bpp(decoded:sub(1, expected)),
      width,
      height
    ),
  }
end

local function speciesDimensions(rom, profile, species)
  local record = symbol(profile, "BaseData").offset + (species - 1) * 32
  local dimensions = rom:readByte(record + 17)
  local width = math.floor(dimensions / 16)
  local height = dimensions % 16
  if width < 1 or height < 1 or width > 7 or height > 7 then
    error(("Crystal species %d has invalid pic dimensions")
      :format(species), 3)
  end
  return width, height
end

local function extractSpeciesPic(rom, profile, tableOffset, species, face)
  local offset = readPicPointer(rom, tableOffset, species, face)
  if not offset then
    return Json.null
  end
  local width, height
  if face == "back" then
    width, height = BACK_TILES, BACK_TILES
  else
    width, height = speciesDimensions(rom, profile, species)
  end
  local picture = decompressPicture(rom, offset, width, height)
  picture.palette = pokemonPalette(rom, profile, species, false)
  picture.shinyPalette = pokemonPalette(rom, profile, species, true)
  return picture
end

local function extractPlayerBack(rom, profile, name, classIndex, storage)
  local offset = symbol(profile, name).offset
  local expected = BACK_TILES * BACK_TILES * 16
  local data
  if storage == "lz" then
    local bankRemaining = 0x4000 - (offset % 0x4000)
    data = CrystalLz.decompress(
      rom:readString(offset, bankRemaining),
      { maxOutputSize = MAX_PIC_BYTES }
    )
  else
    data = rom:readString(offset, expected)
  end
  if #data < expected then
    error(("Crystal player back pic at 0x%X decoded to %d bytes; expected >= %d")
      :format(offset, #data, expected), 3)
  end
  local picture = {
    widthTiles = BACK_TILES,
    heightTiles = BACK_TILES,
    tiles = TileDecoder.decode2bpp(data:sub(1, expected)),
  }
  picture.palette = trainerPalette(rom, profile, classIndex)
  return picture
end

function CrystalBattlePics.extract(rom, profile, options)
  options = options or {}
  local tableOffset = symbol(profile, "PokemonPicPointers").offset
  local speciesFilter = options.species
  local records = Json.array({})

  local function include(species)
    if not speciesFilter then return true end
    for _, value in ipairs(speciesFilter) do
      if value == species then return true end
    end
    return false
  end

  for species = 1, SPECIES_COUNT do
    if include(species) then
      records[species] = {
        number = species,
        front = extractSpeciesPic(
          rom, profile, tableOffset, species, "front"),
        back = extractSpeciesPic(
          rom, profile, tableOffset, species, "back"),
      }
    end
  end

  return {
    schema = 1,
    layout = "crystal.battle.layout.v1",
    count = SPECIES_COUNT,
    species = records,
    player = {
      -- Pinned pokecrystal stores Chris as .2bpp.lz and Kris as raw .2bpp.
      male = extractPlayerBack(rom, profile, "ChrisBackpic", 0, "lz"),
      female = extractPlayerBack(rom, profile, "KrisBackpic", 1, "raw"),
    },
  }
end

function CrystalBattlePics.speciesNumber(speciesId)
  if type(speciesId) ~= "string" then return nil end
  local number = speciesId:match("^crystal%.species%.(%d+)")
  return number and tonumber(number) or nil
end

CrystalBattlePics.SPECIES_COUNT = SPECIES_COUNT
CrystalBattlePics.PICS_FIX = PICS_FIX

return CrystalBattlePics
