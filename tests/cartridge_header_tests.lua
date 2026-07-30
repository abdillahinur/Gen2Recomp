return function(test, equal, truthy, raises)
  local CartridgeHeader = require("src.import.CartridgeHeader")
  local Rom = require("src.import.Rom")
  local Fixture = require("tests.fixtures.Cartridge")

  test("CartridgeHeader parses CGB metadata and size declarations", function()
    local header = CartridgeHeader.parse(Rom.new(Fixture.build({
      version = 0x02,
    })))

    equal(header.title, "TEST TITLE")
    equal(header.manufacturerCode, "ABCD")
    equal(header.cgbFlag, 0xc0)
    equal(header.newLicenseeCode, "01")
    equal(header.cartridgeType, 0x10)
    equal(header.cartridgeTypeName, "MBC3+TIMER+RAM+BATTERY")
    equal(header.declaredRomSize, 32 * 1024)
    equal(header.declaredRomBanks, 2)
    equal(header.declaredRamSize, 32 * 1024)
    equal(header.declaredRamBanks, 4)
    equal(header.destinationCode, 1)
    equal(header.oldLicenseeCode, 0x33)
    equal(header.version, 2)
    truthy(header.declaredRomSizeMatches)
  end)

  test("CartridgeHeader validates both cartridge checksums", function()
    local header = CartridgeHeader.parse(Rom.new(Fixture.build()))

    truthy(header.headerChecksumValid)
    truthy(header.globalChecksumValid)
    equal(header.headerChecksum, header.calculatedHeaderChecksum)
    equal(header.globalChecksum, header.calculatedGlobalChecksum)
  end)

  test("CartridgeHeader detects header and body corruption separately", function()
    local fixture = Fixture.build()
    local changedHeader =
      Fixture.replaceByte(fixture, 0x0134, string.byte("X"))
    local header = CartridgeHeader.parse(Rom.new(changedHeader))
    truthy(not header.headerChecksumValid)
    truthy(not header.globalChecksumValid)

    local changedBody = Fixture.replaceByte(fixture, 0x0200, 1)
    header = CartridgeHeader.parse(Rom.new(changedBody))
    truthy(header.headerChecksumValid)
    truthy(not header.globalChecksumValid)
  end)

  test("CartridgeHeader exposes unknown size codes without guessing", function()
    local fixture = Fixture.replaceByte(Fixture.build(), 0x0148, 0x7f)
    local header = CartridgeHeader.parse(Rom.new(fixture))

    equal(header.romSizeCode, 0x7f)
    equal(header.declaredRomSize, nil)
    truthy(not header.declaredRomSizeMatches)
  end)

  test("CartridgeHeader rejects truncated files and non-ROM readers", function()
    raises(function()
      CartridgeHeader.parse(Rom.new(string.rep("\0", 0x014f)))
    end, "too small")
    raises(function()
      CartridgeHeader.parse({})
    end, "requires a ROM reader")
  end)
end
