local CartridgeHeader = require("src.import.CartridgeHeader")
local Profiles = require("src.import.Profiles")
local Rom = require("src.import.Rom")
local Sha1 = require("src.import.Sha1")

local RomIdentifier = {}

local HEADER_FIELDS = {
  "title",
  "manufacturerCode",
  "cgbFlag",
  "newLicenseeCode",
  "sgbFlag",
  "cartridgeType",
  "romSizeCode",
  "ramSizeCode",
  "destinationCode",
  "oldLicenseeCode",
  "version",
  "logoSha1",
}

local function formatValue(value)
  if type(value) == "string" then
    return ("%q"):format(value)
  end
  if type(value) == "number" then
    return ("0x%X"):format(value)
  end
  return tostring(value)
end

local function appendProfileMismatches(report)
  local profile = report.profile
  if profile.expectedSize and profile.expectedSize ~= report.size then
    report.errors[#report.errors + 1] =
      ("profile size mismatch: expected 0x%X, got 0x%X")
      :format(profile.expectedSize, report.size)
  end

  local expectedHeader = profile.expectedHeader or {}
  for _, field in ipairs(HEADER_FIELDS) do
    local expected = expectedHeader[field]
    local actual = report.header[field]
    if expected ~= nil and expected ~= actual then
      report.errors[#report.errors + 1] =
        ("profile header mismatch for %s: expected %s, got %s")
        :format(field, formatValue(expected), formatValue(actual))
    end
  end
end

function RomIdentifier.inspect(data, registry)
  registry = registry or Profiles

  if type(registry) ~= "table"
      or type(registry.identifySha1) ~= "function" then
    error("ROM identifier requires a profile registry", 2)
  end

  local rom = Rom.new(data)
  local raw = rom:readString(0, rom:size())
  local report = {
    accepted = false,
    size = rom:size(),
    sha1 = Sha1.hex(raw),
    profile = nil,
    header = nil,
    errors = {},
    warnings = {},
  }
  raw = nil

  report.profile = registry.identifySha1(report.sha1)
  if not report.profile then
    report.errors[#report.errors + 1] =
      "ROM SHA-1 does not match a supported profile"
  end

  local parsed, headerOrError = pcall(CartridgeHeader.parse, rom)
  if not parsed then
    report.errors[#report.errors + 1] =
      "cartridge header is invalid: " .. tostring(headerOrError)
    return report
  end

  report.header = headerOrError
  if not report.header.headerChecksumValid then
    report.errors[#report.errors + 1] = "cartridge header checksum is invalid"
  end
  if report.header.declaredRomSize == nil then
    report.errors[#report.errors + 1] =
      ("unknown cartridge ROM-size code 0x%02X")
      :format(report.header.romSizeCode)
  elseif not report.header.declaredRomSizeMatches then
    report.errors[#report.errors + 1] =
      ("cartridge header declares 0x%X bytes, file contains 0x%X")
      :format(report.header.declaredRomSize, report.size)
  end
  if not report.header.globalChecksumValid then
    report.warnings[#report.warnings + 1] =
      "cartridge global checksum is invalid"
  end

  if report.profile then
    appendProfileMismatches(report)
  end

  report.accepted = report.profile ~= nil and #report.errors == 0
  return report
end

return RomIdentifier
