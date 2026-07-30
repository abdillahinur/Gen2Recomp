local Sha1 = require("src.import.Sha1")

local CartridgeHeader = {}

local HEADER_END = 0x014f
local LOGO_OFFSET = 0x0104
local LOGO_LENGTH = 0x30

local ROM_SIZES = {
  [0x00] = { bytes = 32 * 1024, banks = 2 },
  [0x01] = { bytes = 64 * 1024, banks = 4 },
  [0x02] = { bytes = 128 * 1024, banks = 8 },
  [0x03] = { bytes = 256 * 1024, banks = 16 },
  [0x04] = { bytes = 512 * 1024, banks = 32 },
  [0x05] = { bytes = 1024 * 1024, banks = 64 },
  [0x06] = { bytes = 2 * 1024 * 1024, banks = 128 },
  [0x07] = { bytes = 4 * 1024 * 1024, banks = 256 },
  [0x08] = { bytes = 8 * 1024 * 1024, banks = 512 },
  [0x52] = { bytes = 72 * 16 * 1024, banks = 72 },
  [0x53] = { bytes = 80 * 16 * 1024, banks = 80 },
  [0x54] = { bytes = 96 * 16 * 1024, banks = 96 },
}

local RAM_SIZES = {
  [0x00] = { bytes = 0, banks = 0 },
  [0x01] = { bytes = nil, banks = nil },
  [0x02] = { bytes = 8 * 1024, banks = 1 },
  [0x03] = { bytes = 32 * 1024, banks = 4 },
  [0x04] = { bytes = 128 * 1024, banks = 16 },
  [0x05] = { bytes = 64 * 1024, banks = 8 },
}

local CARTRIDGE_TYPES = {
  [0x00] = "ROM ONLY",
  [0x01] = "MBC1",
  [0x02] = "MBC1+RAM",
  [0x03] = "MBC1+RAM+BATTERY",
  [0x05] = "MBC2",
  [0x06] = "MBC2+BATTERY",
  [0x08] = "ROM+RAM",
  [0x09] = "ROM+RAM+BATTERY",
  [0x0f] = "MBC3+TIMER+BATTERY",
  [0x10] = "MBC3+TIMER+RAM+BATTERY",
  [0x11] = "MBC3",
  [0x12] = "MBC3+RAM",
  [0x13] = "MBC3+RAM+BATTERY",
  [0x19] = "MBC5",
  [0x1a] = "MBC5+RAM",
  [0x1b] = "MBC5+RAM+BATTERY",
  [0x1c] = "MBC5+RUMBLE",
  [0x1d] = "MBC5+RUMBLE+RAM",
  [0x1e] = "MBC5+RUMBLE+RAM+BATTERY",
}

local function trimZeroPadding(value)
  local zero = value:find("\0", 1, true)
  if zero then
    return value:sub(1, zero - 1)
  end
  return value
end

local function calculateHeaderChecksum(rom)
  local checksum = 0
  for offset = 0x0134, 0x014c do
    checksum = (checksum - rom:readByte(offset) - 1) % 0x100
  end
  return checksum
end

local function calculateGlobalChecksum(rom)
  local checksum = 0
  local chunkSize = 64 * 1024

  for chunkOffset = 0, rom:size() - 1, chunkSize do
    local length = math.min(chunkSize, rom:size() - chunkOffset)
    local chunk = rom:readString(chunkOffset, length)

    for index = 1, #chunk do
      local offset = chunkOffset + index - 1
      if offset ~= 0x014e and offset ~= 0x014f then
        checksum = (checksum + chunk:byte(index)) % 0x10000
      end
    end
  end

  return checksum
end

function CartridgeHeader.parse(rom)
  if type(rom) ~= "table"
      or type(rom.size) ~= "function"
      or type(rom.readByte) ~= "function"
      or type(rom.readString) ~= "function" then
    error("cartridge header requires a ROM reader", 2)
  end
  if rom:size() <= HEADER_END then
    error(("ROM is too small for a cartridge header: "
      .. "need at least 0x%X bytes, got 0x%X")
      :format(HEADER_END + 1, rom:size()), 2)
  end

  local cgbFlag = rom:readByte(0x0143)
  local titleLength = cgbFlag >= 0x80 and 11 or 16
  local romSizeCode = rom:readByte(0x0148)
  local ramSizeCode = rom:readByte(0x0149)
  local romSize = ROM_SIZES[romSizeCode]
  local ramSize = RAM_SIZES[ramSizeCode]
  local storedHeaderChecksum = rom:readByte(0x014d)
  local calculatedHeaderChecksum = calculateHeaderChecksum(rom)
  local storedGlobalChecksum = rom:readByte(0x014e) * 0x100
    + rom:readByte(0x014f)
  local calculatedGlobalChecksum = calculateGlobalChecksum(rom)
  local cartridgeType = rom:readByte(0x0147)

  return {
    title = trimZeroPadding(rom:readString(0x0134, titleLength)),
    manufacturerCode = trimZeroPadding(rom:readString(0x013f, 4)),
    cgbFlag = cgbFlag,
    newLicenseeCode = rom:readString(0x0144, 2),
    sgbFlag = rom:readByte(0x0146),
    cartridgeType = cartridgeType,
    cartridgeTypeName = CARTRIDGE_TYPES[cartridgeType],
    romSizeCode = romSizeCode,
    declaredRomSize = romSize and romSize.bytes or nil,
    declaredRomBanks = romSize and romSize.banks or nil,
    ramSizeCode = ramSizeCode,
    declaredRamSize = ramSize and ramSize.bytes or nil,
    declaredRamBanks = ramSize and ramSize.banks or nil,
    destinationCode = rom:readByte(0x014a),
    oldLicenseeCode = rom:readByte(0x014b),
    version = rom:readByte(0x014c),
    logoSha1 = Sha1.hex(rom:readString(LOGO_OFFSET, LOGO_LENGTH)),
    headerChecksum = storedHeaderChecksum,
    calculatedHeaderChecksum = calculatedHeaderChecksum,
    headerChecksumValid = storedHeaderChecksum == calculatedHeaderChecksum,
    globalChecksum = storedGlobalChecksum,
    calculatedGlobalChecksum = calculatedGlobalChecksum,
    globalChecksumValid = storedGlobalChecksum == calculatedGlobalChecksum,
    declaredRomSizeMatches = romSize ~= nil
      and romSize.bytes == rom:size(),
  }
end

CartridgeHeader.MINIMUM_SIZE = HEADER_END + 1
CartridgeHeader.ROM_SIZES = ROM_SIZES
CartridgeHeader.RAM_SIZES = RAM_SIZES

return CartridgeHeader
