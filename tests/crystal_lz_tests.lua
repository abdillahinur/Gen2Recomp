return function(test, equal, truthy, raises)
  local CrystalLz = require("src.import.CrystalLz")

  test("CrystalLz decodes literal and sequence commands", function()
    local source = string.char(
      0x02, 0x41, 0x42, 0x43,
      0x22, 0x78,
      0x44, 0x79, 0x7a,
      0x61,
      0xff
    )
    local output, report = CrystalLz.decompress(source)
    equal(output, "ABCxxxyzyzy\0\0")
    equal(report.consumedBytes, #source)
    equal(report.commandCount, 4)
  end)

  test("CrystalLz decodes repeat flip and reverse lookbacks", function()
    local source = string.char(
      0x02, 0x41, 0x42, 0x43,
      0x85, 0x82,
      0xa2, 0x00, 0x00,
      0xc2, 0x00, 0x02,
      0xff
    )
    local output = CrystalLz.decompress(source)
    equal(output:sub(1, 9), "ABCABCABC")
    equal(output:byte(10), 0x82)
    equal(output:byte(11), 0x42)
    equal(output:byte(12), 0xc2)
    equal(output:sub(13), "CBA")
  end)

  test("CrystalLz decodes long commands and enforces limits", function()
    local source = string.char(0xef, 0xff, 0xff)
    local output = CrystalLz.decompress(source, {
      maxOutputSize = 1024,
    })
    equal(#output, 1024)
    equal(output, string.rep("\0", 1024))

    raises(function()
      CrystalLz.decompress(source, { maxOutputSize = 1023 })
    end, "configured limit")
  end)

  test("CrystalLz rejects malformed streams", function()
    raises(function()
      CrystalLz.decompress(string.char(0x00))
    end, "literal data")
    raises(function()
      CrystalLz.decompress(string.char(0x80, 0x80, 0xff))
    end, "outside prior output")
    raises(function()
      CrystalLz.decompress(string.char(0xfc, 0x00))
    end, "invalid Crystal LZ")
    raises(function()
      CrystalLz.decompress(nil)
    end, "binary string")
    truthy(true)
  end)
end
