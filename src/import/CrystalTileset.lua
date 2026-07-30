local CrystalLz = require("src.import.CrystalLz")
local CgbPalette = require("src.import.CgbPalette")
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
local TILESET_HEADER_SIZE = 15

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
      local palette = CgbPalette.decodePalette(data, offset)
      palette.id = index - 1
      palette.name = paletteName
      palettes[#palettes + 1] = palette
      offset = offset + 8
    end
    result.timeOfDay[setName] = palettes
  end
  for index, name in ipairs({ "morningDay", "night" }) do
    local palette = CgbPalette.decodePalette(data, offset)
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

local function decodeMetatiles(data, expectedCount)
  expectedCount = expectedCount or METATILE_COUNT
  if #data ~= expectedCount * METATILE_SIZE then
    error(("Crystal metatile length is %d; expected %d")
      :format(#data, expectedCount * METATILE_SIZE), 3)
  end

  local records = Json.array({})
  for id = 0, expectedCount - 1 do
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

local function decodeCollision(data, expectedCount)
  expectedCount = expectedCount or METATILE_COUNT
  if #data ~= expectedCount * COLLISION_SIZE then
    error(("Crystal collision length is %d; expected %d")
      :format(#data, expectedCount * COLLISION_SIZE), 3)
  end

  local records = Json.array({})
  for id = 0, expectedCount - 1 do
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

local function readDataAddress(rom, offset)
  return {
    bank = rom:readByte(offset),
    address = rom:readWord(offset + 1),
  }
end

function CrystalTileset.extractById(
    rom,
    profile,
    id,
    name,
    requiredMetatileCount)
  if type(id) ~= "number" or id < 1 or id % 1 ~= 0 then
    error("Crystal tileset id must be a positive integer", 2)
  end
  local tableStart = requireSymbol(profile, "Tilesets")
  local offset = tableStart.offset + id * TILESET_HEADER_SIZE
  local gfx = readDataAddress(rom, offset)
  local meta = readDataAddress(rom, offset + 3)
  local collision = readDataAddress(rom, offset + 6)
  local paletteAddress = rom:readWord(offset + 13)
  local compressed = rom:string(
    gfx.bank,
    gfx.address,
    0x8000 - gfx.address
  )
  local graphics, compression = CrystalLz.decompress(compressed, {
    maxOutputSize = GRAPHIC_TILE_COUNT * 16,
  })
  if #graphics == 0
      or #graphics % 16 ~= 0
      or #graphics > GRAPHIC_TILE_COUNT * 16 then
    error(("Crystal tileset %d graphics decode to invalid length %d")
      :format(id, #graphics), 2)
  end
  local graphicTileCount = #graphics / 16
  local metaOffset = rom:offset(meta.bank, meta.address, 1)
  local collisionOffset =
    rom:offset(collision.bank, collision.address, 1)
  local metaBytes = collisionOffset - metaOffset
  if metaBytes <= 0 or metaBytes % METATILE_SIZE ~= 0 then
    error(("Crystal tileset %d has invalid metatile boundaries")
      :format(id), 2)
  end
  local availableMetatileCount = metaBytes / METATILE_SIZE
  local metatileCount =
    requiredMetatileCount or availableMetatileCount
  if metatileCount < 1
      or metatileCount > availableMetatileCount
      or metatileCount > METATILE_COUNT then
    error(("Crystal tileset %d has too many metatiles")
      :format(id), 2)
  end

  local basePalettes = requireSymbol(profile, "TilesetBGPalette")
  return {
    schema = 1,
    id = name or ("tileset_%d"):format(id),
    numericId = id,
    graphics = {
      format = "2bpp",
      tileCount = graphicTileCount,
      tiles = TileDecoder.decode2bpp(graphics),
      compressedBytes = compression.consumedBytes,
      consumedBytes = compression.consumedBytes,
      commandCount = compression.commandCount,
    },
    tileSlots = decodePaletteMap(
      rom:string(tableStart.bank, paletteAddress, PALETTE_MAP_SIZE)
    ),
    metatiles = {
      count = metatileCount,
      records = decodeMetatiles(rom:string(
        meta.bank,
        meta.address,
        metatileCount * METATILE_SIZE
      ), metatileCount),
    },
    collision = {
      count = metatileCount,
      records = decodeCollision(rom:string(
        collision.bank,
        collision.address,
        metatileCount * COLLISION_SIZE
      ), metatileCount),
    },
    palettes = decodePalettes(rom:readString(
      basePalettes.offset,
      BASE_PALETTE_SIZE
    )),
  }
end

function CrystalTileset.extractMany(rom, profile, specs)
  local results = Json.array({})
  for _, spec in ipairs(specs) do
    results[#results + 1] = CrystalTileset.extractById(
      rom,
      profile,
      spec.id,
      spec.name,
      spec.metatileCount
    )
  end
  return results
end

CrystalTileset.GRAPHIC_TILE_COUNT = GRAPHIC_TILE_COUNT
CrystalTileset.TILE_SLOT_COUNT = TILE_SLOT_COUNT
CrystalTileset.METATILE_COUNT = METATILE_COUNT
CrystalTileset.BASE_PALETTE_SIZE = BASE_PALETTE_SIZE

return CrystalTileset
