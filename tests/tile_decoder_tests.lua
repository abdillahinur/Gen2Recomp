return function(test, equal, truthy, raises)
  local TileDecoder = require("src.import.TileDecoder")

  test("TileDecoder decodes 1bpp rows most-significant-bit first", function()
    local tiles = TileDecoder.decode1bpp(
      string.char(0x81) .. string.rep("\0", 7)
    )
    equal(#tiles, 1)
    equal(#tiles[1], 64)
    equal(tiles[1][1], 1)
    equal(tiles[1][2], 0)
    equal(tiles[1][8], 1)
    equal(tiles[1][9], 0)
  end)

  test("TileDecoder combines both 2bpp planes", function()
    local firstRow = string.char(0x80, 0x40)
    local tiles = TileDecoder.decode2bpp(
      firstRow .. string.rep("\0", 14)
    )
    equal(tiles[1][1], 1)
    equal(tiles[1][2], 2)
    equal(tiles[1][3], 0)
  end)

  test("TileDecoder requires complete tiles", function()
    raises(function() TileDecoder.decode1bpp("short") end, "multiple of 8")
    raises(function() TileDecoder.decode2bpp("short") end, "multiple of 16")
    raises(function() TileDecoder.decode1bpp(nil) end, "binary string")
    truthy(true)
  end)
end
