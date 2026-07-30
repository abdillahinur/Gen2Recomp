local Json = require("src.core.Json")

local CgbPalette = {}

local function expand5(value)
  return math.floor(value * 255 / 31 + 0.5)
end

function CgbPalette.decodeColor(low, high)
  if type(low) ~= "number" or type(high) ~= "number" then
    error("CGB color bytes must be numbers", 2)
  end
  local raw = low + high * 0x100
  if raw >= 0x8000 then
    error("CGB palette color has its unused high bit set", 2)
  end

  local red = raw % 0x20
  local green = math.floor(raw / 0x20) % 0x20
  local blue = math.floor(raw / 0x400) % 0x20
  return {
    bgr15 = raw,
    rgb5 = Json.array({ red, green, blue }),
    rgb8 = Json.array({
      expand5(red),
      expand5(green),
      expand5(blue),
    }),
  }
end

function CgbPalette.decodeColorAt(data, offset)
  if type(data) ~= "string" then
    error("CGB palette data must be a binary string", 2)
  end
  offset = offset or 1
  if offset < 1 or offset + 1 > #data then
    error("CGB color offset is out of bounds", 2)
  end
  return CgbPalette.decodeColor(
    data:byte(offset),
    data:byte(offset + 1)
  )
end

function CgbPalette.decodePalette(data, offset, colorCount)
  offset = offset or 1
  colorCount = colorCount or 4
  local colors = Json.array({})
  for index = 0, colorCount - 1 do
    colors[#colors + 1] =
      CgbPalette.decodeColorAt(data, offset + index * 2)
  end
  return { colors = colors }
end

return CgbPalette
