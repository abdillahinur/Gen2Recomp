local CrystalLz = require("src.import.CrystalLz")
local Json = require("src.core.Json")
local TileDecoder = require("src.import.TileDecoder")

local CrystalTileset = {}

local GRAPHIC_TILE_COUNT = 192
local TILE_SLOT_COUNT = 224
local METATILE_COUNT = 128
local METATILE_SIZE = 16
local COLLISION_SIZE = 4
local PALETTE_MAP_SIZE = TILE_SLOT_COUNT / 2
local BASE_PALETTE_SIZE = 5 * 8 * 4 * 2 + 2 * 4 * 2

local TIME_SETS = {
  "morning",
  "day",
  "night",
  "dark",
  "indoor",
}

local PALETTE_NAMES = {
  "gray",
  "red",
  "green",
  "water",
  "yellow",
  "brown",
  "roof",
  "text",
}

local function requireSymbol(profile, name)
  local symbol = profile.symbols and profile.symbols[name]
  if type(symbol) ~= "table" or type(symbol.offset) ~= "number" then
    error("tileset profile is missing symbol " .. name, 3)
  end
  return symbol
end

local function requireRange(startSymbol, endSymbol, expected, name)
  local length = endSymbol.offset - startSymbol.offset
  if length ~= expected then
    error(("%s length is %d; expected %d")
      :format(name, length, expected), 3)
  end
  return length
end

local function decodeColor(data, offset)
  local raw = data:byte(offset) + data:byte(offset + 1) * 0x100
  if raw >= 0x8000 then
    error("Crystal palette color has its unused high bit set", 3)
  end
  local red = raw % 0x20
  local green = math.floor(raw / 0x20) % 0x20
  local blue = math.floor(raw / 0x400) % 0x20
  local function expand(value)
    return math.floor(value * 255 / 31 + 0.5)
  end
  return {
    bgr15 = raw,
    rgb5 = Json.array({ red, green, blue }),
    rgb8 = Json.array({
      expand(red),
      expand(green),
      expand(blue),
    }),
  }
end

local function decodePalette(data, offset)
  local colors = Json.array({})
  for color = 0, 3 do
    colors[#colors + 1] = decodeColor(data, offset + color * 2)
  end
  return { colors = colors }
end

local function decodePalettes(data)
  if #data ~= BASE_PALETTE_SIZE then
    error(("Crystal base palette length is %d; expected %d")
      :format(#data, BASE_PALETTE_SIZE), 3)
  end

  local result = {
    timeOfDay = {},
    overworldWater = Json.array({}),
  }
  local offset = 1
  for _, setName in ipairs(TIME_SETS) do
    local palettes = Json.array({})
    for index, paletteName in ipairs(PALETTE_NAMES) do
      local palette = decodePalette(data, offset)
      palette.id = index - 1
      palette.name = paletteName
      palettes[#palettes + 1] = palette
      offset = offset + 8
    end
    result.timeOfDay[setName] = palettes
  end
  for index, name in ipairs({ "morningDay", "night" }) do
    local palette = decodePalette(data, offset)
    palette.id = index - 1
    palette.name = name
    result.overworldWater[#result.overworldWater + 1] = palette
    offset = offset + 8
  end
  return result
end

local function sourceGraphicIndex(encodedTileId)
  if encodedTileId < 96 then
    return encodedTileId
  elseif encodedTileId < 128 then
    return Json.null
  end
  return encodedTileId - 32
end

local function decodePaletteMap(data)
  if #data ~= PALETTE_MAP_SIZE then
    error(("Crystal Johto palette map length is %d; expected %d")
      :format(#data, PALETTE_MAP_SIZE), 3)
  end

  local slots = Json.array({})
  for byteIndex = 1, #data do
    local packed = data:byte(byteIndex)
    for half = 0, 1 do
      local encodedTileId = (byteIndex - 1) * 2 + half
      local attribute = math.floor(packed / 2 ^ (half * 4)) % 0x10
      local slot = {
        encodedTileId = encodedTileId,
        runtimeTileId = encodedTileId % 0x80,
        vramBank = math.floor(attribute / 8),
        paletteId = attribute % 8,
        graphicIndex = sourceGraphicIndex(encodedTileId),
      }
      if encodedTileId < 96 and slot.vramBank ~= 0 then
        error("Johto bank-0 tile slot selects the wrong VRAM bank", 3)
      elseif encodedTileId >= 96 and slot.vramBank ~= 1 then
        error("Johto reserved/bank-1 tile slot selects the wrong VRAM bank", 3)
      end
      slots[#slots + 1] = slot
    end
  end
  return slots
end

local function decodeMetatiles(data)
  if #data ~= METATILE_COUNT * METATILE_SIZE then
    error(("Crystal Johto metatile length is %d; expected %d")
      :format(#data, METATILE_COUNT * METATILE_SIZE), 3)
  end

  local records = Json.array({})
  for id = 0, METATILE_COUNT - 1 do
    local tileIds = Json.array({})
    local start = id * METATILE_SIZE + 1
    for index = 0, METATILE_SIZE - 1 do
      local tileId = data:byte(start + index)
      if tileId >= TILE_SLOT_COUNT then
        error(("metatile %d references unavailable tile %d")
          :format(id, tileId), 3)
      end
      tileIds[#tileIds + 1] = tileId
    end
    records[#records + 1] = {
      id = id,
      widthTiles = 4,
      heightTiles = 4,
      tileIds = tileIds,
    }
  end
  return records
end

local function decodeCollision(data)
  if #data ~= METATILE_COUNT * COLLISION_SIZE then
    error(("Crystal Johto collision length is %d; expected %d")
      :format(#data, METATILE_COUNT * COLLISION_SIZE), 3)
  end

  local records = Json.array({})
  for id = 0, METATILE_COUNT - 1 do
    local start = id * COLLISION_SIZE + 1
    records[#records + 1] = {
      id = id,
      topLeft = data:byte(start),
      topRight = data:byte(start + 1),
      bottomLeft = data:byte(start + 2),
      bottomRight = data:byte(start + 3),
    }
  end
  return records
end

function CrystalTileset.extractJohto(rom, profile)
  local gfx = requireSymbol(profile, "TilesetJohtoGFX")
  local meta = requireSymbol(profile, "TilesetJohtoMeta")
  local collision = requireSymbol(profile, "TilesetJohtoColl")
  local nextGfx = requireSymbol(profile, "TilesetIcePathGFX")
  local paletteMap = requireSymbol(profile, "TilesetJohtoPalMap")
  local nextPaletteMap =
    requireSymbol(profile, "TilesetJohtoModernPalMap")
  local basePalettes = requireSymbol(profile, "TilesetBGPalette")
  local palettesEnd = requireSymbol(profile, "MapObjectPals")

  requireRange(
    meta,
    collision,
    METATILE_COUNT * METATILE_SIZE,
    "Crystal Johto metatile"
  )
  requireRange(
    collision,
    nextGfx,
    METATILE_COUNT * COLLISION_SIZE,
    "Crystal Johto collision"
  )
  requireRange(
    paletteMap,
    nextPaletteMap,
    PALETTE_MAP_SIZE,
    "Crystal Johto palette map"
  )
  requireRange(
    basePalettes,
    palettesEnd,
    BASE_PALETTE_SIZE,
    "Crystal base palette"
  )

  local compressed = rom:readString(
    gfx.offset,
    meta.offset - gfx.offset
  )
  local graphics, compression = CrystalLz.decompress(compressed, {
    maxOutputSize = GRAPHIC_TILE_COUNT * 16,
  })
  if #graphics ~= GRAPHIC_TILE_COUNT * 16 then
    error(("Crystal Johto graphics decode to %d bytes; expected %d")
      :format(#graphics, GRAPHIC_TILE_COUNT * 16), 2)
  end

  return {
    schema = 1,
    id = "johto",
    graphics = {
      format = "2bpp",
      tileCount = GRAPHIC_TILE_COUNT,
      tiles = TileDecoder.decode2bpp(graphics),
      compressedBytes = #compressed,
      consumedBytes = compression.consumedBytes,
      commandCount = compression.commandCount,
    },
    tileSlots = decodePaletteMap(
      rom:readString(paletteMap.offset, PALETTE_MAP_SIZE)
    ),
    metatiles = {
      count = METATILE_COUNT,
      records = decodeMetatiles(rom:readString(
        meta.offset,
        METATILE_COUNT * METATILE_SIZE
      )),
    },
    collision = {
      count = METATILE_COUNT,
      records = decodeCollision(rom:readString(
        collision.offset,
        METATILE_COUNT * COLLISION_SIZE
      )),
    },
    palettes = decodePalettes(rom:readString(
      basePalettes.offset,
      BASE_PALETTE_SIZE
    )),
  }
end

CrystalTileset.GRAPHIC_TILE_COUNT = GRAPHIC_TILE_COUNT
CrystalTileset.TILE_SLOT_COUNT = TILE_SLOT_COUNT
CrystalTileset.METATILE_COUNT = METATILE_COUNT
CrystalTileset.BASE_PALETTE_SIZE = BASE_PALETTE_SIZE

return CrystalTileset
