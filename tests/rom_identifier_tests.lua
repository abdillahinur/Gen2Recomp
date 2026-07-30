return function(test, equal, truthy)
  local CartridgeHeader = require("src.import.CartridgeHeader")
  local Rom = require("src.import.Rom")
  local RomIdentifier = require("src.import.RomIdentifier")
  local Sha1 = require("src.import.Sha1")
  local Fixture = require("tests.fixtures.Cartridge")

  local function buildFixture()
    return Fixture.build({
      title = "IDENTIFIER",
      manufacturerCode = "TEST",
    })
  end

  local function registryFor(profile)
    return {
      identifySha1 = function(sha1)
        if sha1 == profile.sha1 then
          return profile
        end
        return nil
      end,
    }
  end

  local function matchingProfile(data)
    local header = CartridgeHeader.parse(Rom.new(data))
    return {
      id = "synthetic",
      sha1 = Sha1.hex(data),
      expectedSize = #data,
      expectedHeader = {
        title = header.title,
        manufacturerCode = header.manufacturerCode,
        cgbFlag = header.cgbFlag,
        newLicenseeCode = header.newLicenseeCode,
        sgbFlag = header.sgbFlag,
        cartridgeType = header.cartridgeType,
        romSizeCode = header.romSizeCode,
        ramSizeCode = header.ramSizeCode,
        destinationCode = header.destinationCode,
        oldLicenseeCode = header.oldLicenseeCode,
        version = header.version,
        logoSha1 = header.logoSha1,
      },
    }
  end

  test("RomIdentifier accepts an exact hash and header profile", function()
    local data = buildFixture()
    local profile = matchingProfile(data)
    local report = RomIdentifier.inspect(data, registryFor(profile))

    truthy(report.accepted)
    equal(report.profile, profile)
    equal(report.sha1, profile.sha1)
    equal(#report.errors, 0)
    equal(#report.warnings, 0)
  end)

  test("RomIdentifier rejects unsupported hashes", function()
    local data = buildFixture()
    local report = RomIdentifier.inspect(data, {
      identifySha1 = function() return nil end,
    })

    truthy(not report.accepted)
    truthy(report.errors[1]:match("supported profile"))
    truthy(report.header.headerChecksumValid)
  end)

  test("RomIdentifier rejects profile metadata mismatches", function()
    local data = buildFixture()
    local profile = matchingProfile(data)
    profile.expectedHeader.title = "WRONG"
    local report = RomIdentifier.inspect(data, registryFor(profile))

    truthy(not report.accepted)
    truthy(report.errors[1]:match("title"))
  end)

  test("RomIdentifier returns a rejection report for truncated files", function()
    local data = "not a cartridge"
    local profile = {
      id = "truncated",
      sha1 = Sha1.hex(data),
      expectedSize = #data,
    }
    local report = RomIdentifier.inspect(data, registryFor(profile))

    truthy(not report.accepted)
    equal(report.header, nil)
    truthy(report.errors[1]:match("cartridge header"))
  end)
end
