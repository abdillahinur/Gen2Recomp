return function(test, equal, truthy, raises)
  local Rom = require("src.import.Rom")

  local function bankedFixture()
    return string.rep(string.char(0x10), Rom.BANK_SIZE)
      .. string.rep(string.char(0x21), Rom.BANK_SIZE)
      .. string.rep(string.char(0x32), Rom.BANK_SIZE)
  end

  test("Rom reports size and bank count", function()
    local rom = Rom.new(string.rep("\0", Rom.BANK_SIZE * 2 + 7))
    equal(rom:size(), Rom.BANK_SIZE * 2 + 7)
    equal(rom:bankCount(), 3)
    equal(Rom.new(""):bankCount(), 0)
  end)

  test("Rom reads absolute bytes and little-endian words", function()
    local rom = Rom.new(string.char(0x01, 0x34, 0x12, 0xff))
    equal(rom:readByte(0), 0x01)
    equal(rom:readWord(1), 0x1234)
    equal(rom:readString(1, 2), string.char(0x34, 0x12))

    local bytes = rom:readBytes(0, 4)
    equal(#bytes, 4)
    equal(bytes[4], 0xff)
  end)

  test("Rom maps fixed and switchable bank addresses", function()
    local rom = Rom.new(bankedFixture())

    equal(rom:offset(0, 0x0000), 0x0000)
    equal(rom:offset(0, 0x3fff), 0x3fff)
    equal(rom:offset(1, 0x4000), 0x4000)
    equal(rom:offset(1, 0x7fff), 0x7fff)
    equal(rom:offset(2, 0x4000), 0x8000)
    equal(rom:offset(2, 0x7fff), 0xbfff)

    equal(rom:byte(0, 0x2000), 0x10)
    equal(rom:byte(1, 0x5000), 0x21)
    equal(rom:byte(2, 0x6000), 0x32)
  end)

  test("Rom banked string and byte-array reads share mapping", function()
    local prefix = string.rep("\0", Rom.BANK_SIZE)
    local bank = string.char(0xaa, 0xbb, 0xcc)
      .. string.rep("\0", Rom.BANK_SIZE - 3)
    local rom = Rom.new(prefix .. bank)

    equal(rom:string(1, 0x4000, 3), string.char(0xaa, 0xbb, 0xcc))
    local bytes = rom:bytes(1, 0x4000, 3)
    equal(bytes[1], 0xaa)
    equal(bytes[2], 0xbb)
    equal(bytes[3], 0xcc)
    equal(rom:word(1, 0x4000), 0xbbaa)
  end)

  test("Rom accepts FileData-like sources", function()
    local source = {
      getString = function()
        return string.char(0x7a)
      end,
    }
    equal(Rom.new(source):readByte(0), 0x7a)
  end)

  test("Rom rejects invalid absolute ranges", function()
    local rom = Rom.new(string.char(1, 2, 3))

    raises(function() rom:readByte(-1) end, "offset must be at least")
    raises(function() rom:readByte(3) end, "out of bounds")
    raises(function() rom:readBytes(2, 2) end, "out of bounds")
    raises(function() rom:readWord(2) end, "out of bounds")
    raises(function() rom:readByte(0.5) end, "offset must be an integer")
  end)

  test("Rom rejects invalid bank-address pairs", function()
    local rom = Rom.new(bankedFixture())

    raises(function() rom:byte(0, 0x4000) end,
      "bank 0 address must be between")
    raises(function() rom:byte(1, 0x3fff) end,
      "bank 1 address must be between")
    raises(function() rom:byte(-1, 0x4000) end,
      "bank must be at least")
    raises(function() rom:byte(1.5, 0x4000) end,
      "bank must be an integer")
  end)

  test("Rom prevents banked reads from crossing address windows", function()
    local rom = Rom.new(bankedFixture())

    raises(function() rom:bytes(0, 0x3fff, 2) end,
      "address%-window boundary")
    raises(function() rom:bytes(1, 0x7fff, 2) end,
      "address%-window boundary")
  end)

  test("Rom rejects bank addresses beyond a truncated image", function()
    local rom = Rom.new(string.rep("\0", Rom.BANK_SIZE + 4))

    equal(rom:byte(1, 0x4003), 0)
    raises(function() rom:byte(1, 0x4004) end, "out of bounds")
    raises(function() rom:byte(2, 0x4000) end, "out of bounds")
  end)

  test("Rom rejects unsupported data sources", function()
    raises(function() Rom.new(nil) end, "binary string")
    raises(function() Rom.new({}) end, "binary string")
    raises(function()
      Rom.new({ getString = function() return 123 end })
    end, "must return a string")
  end)
end

