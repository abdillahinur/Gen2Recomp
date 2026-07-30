return function(test, equal, truthy, raises)
  local CgbPalette = require("src.import.CgbPalette")

  test("CgbPalette decodes little-endian RGB555 colors", function()
    local red = CgbPalette.decodeColor(0x1f, 0x00)
    equal(red.bgr15, 0x001f)
    equal(red.rgb5[1], 31)
    equal(red.rgb5[2], 0)
    equal(red.rgb8[1], 255)

    local blue = CgbPalette.decodeColor(0x00, 0x7c)
    equal(blue.rgb5[3], 31)
    equal(blue.rgb8[3], 255)
  end)

  test("CgbPalette decodes bounded palettes", function()
    local data = string.char(
      0x00, 0x00,
      0x1f, 0x00,
      0xe0, 0x03,
      0x00, 0x7c
    )
    local palette = CgbPalette.decodePalette(data)
    equal(#palette.colors, 4)
    equal(palette.colors[3].rgb5[2], 31)
    raises(function()
      CgbPalette.decodePalette(data, 3, 4)
    end, "out of bounds")
    raises(function()
      CgbPalette.decodeColor(0, 0x80)
    end, "high bit")
  end)
end
