local Json = require("src.core.Json")

local TileDecoder = {}

local function bitAt(byte, x)
  return math.floor(byte / 2 ^ (7 - x)) % 2
end

local function requireTileMultiple(data, bytesPerTile, name)
  if type(data) ~= "string" then
    error(name .. " data must be a binary string", 3)
  end
  if #data % bytesPerTile ~= 0 then
    error(("%s data length must be a multiple of %d bytes")
      :format(name, bytesPerTile), 3)
  end
end

function TileDecoder.decode1bpp(data)
  requireTileMultiple(data, 8, "1bpp tile")
  local tiles = Json.array({})

  for offset = 1, #data, 8 do
    local pixels = Json.array({})
    for y = 0, 7 do
      local plane = data:byte(offset + y)
      for x = 0, 7 do
        pixels[#pixels + 1] = bitAt(plane, x)
      end
    end
    tiles[#tiles + 1] = pixels
  end
  return tiles
end

function TileDecoder.decode2bpp(data)
  requireTileMultiple(data, 16, "2bpp tile")
  local tiles = Json.array({})

  for offset = 1, #data, 16 do
    local pixels = Json.array({})
    for y = 0, 7 do
      local low = data:byte(offset + y * 2)
      local high = data:byte(offset + y * 2 + 1)
      for x = 0, 7 do
        pixels[#pixels + 1] = bitAt(low, x) + bitAt(high, x) * 2
      end
    end
    tiles[#tiles + 1] = pixels
  end
  return tiles
end

return TileDecoder
