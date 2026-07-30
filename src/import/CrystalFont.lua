local Json = require("src.core.Json")
local TileDecoder = require("src.import.TileDecoder")

local CrystalFont = {}

local function requireSymbol(profile, name)
  local symbol = profile.symbols and profile.symbols[name]
  if type(symbol) ~= "table" or type(symbol.offset) ~= "number" then
    error("font profile is missing symbol " .. name, 3)
  end
  return symbol
end

local function readRange(rom, profile, firstName, nextName)
  local first = requireSymbol(profile, firstName)
  local following = requireSymbol(profile, nextName)
  local length = following.offset - first.offset
  if length <= 0 then
    error(("font symbol range %s..%s is invalid")
      :format(firstName, nextName), 3)
  end
  return rom:readString(first.offset, length)
end

function CrystalFont.extract(rom, profile)
  local extra = TileDecoder.decode2bpp(
    readRange(rom, profile, "FontExtra", "Font")
  )
  local main = TileDecoder.decode1bpp(
    readRange(rom, profile, "Font", "FontBattleExtra")
  )
  local battleExtra = TileDecoder.decode2bpp(
    readRange(rom, profile, "FontBattleExtra", "Frames")
  )

  if #extra ~= 32 or #main ~= 128 or #battleExtra ~= 32 then
    error(("unexpected Crystal font tile counts: extra=%d main=%d battle=%d")
      :format(#extra, #main, #battleExtra), 2)
  end

  return {
    schema = 1,
    tileWidth = 8,
    tileHeight = 8,
    sets = Json.array({
      {
        id = "extra",
        firstCode = 0x60,
        bitDepth = 2,
        tiles = extra,
      },
      {
        id = "main",
        firstCode = 0x80,
        bitDepth = 1,
        tiles = main,
      },
      {
        id = "battle_extra",
        firstCode = 0x60,
        bitDepth = 2,
        tiles = battleExtra,
      },
    }),
  }
end

return CrystalFont
