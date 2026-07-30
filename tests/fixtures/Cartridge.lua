local Cartridge = {}

local function setByte(bytes, offset, value)
  bytes[offset + 1] = string.char(value)
end

local function setString(bytes, offset, value)
  for index = 1, #value do
    setByte(bytes, offset + index - 1, value:byte(index))
  end
end

function Cartridge.build(options)
  options = options or {}
  local length = options.length or 32 * 1024
  local bytes = {}
  for index = 1, length do
    bytes[index] = "\0"
  end

  setString(bytes, 0x0134, options.title or "TEST TITLE")
  setString(bytes, 0x013f, options.manufacturerCode or "ABCD")
  setByte(bytes, 0x0143, options.cgbFlag or 0xc0)
  setString(bytes, 0x0144, options.newLicenseeCode or "01")
  setByte(bytes, 0x0146, options.sgbFlag or 0x00)
  setByte(bytes, 0x0147, options.cartridgeType or 0x10)
  setByte(bytes, 0x0148, options.romSizeCode or 0x00)
  setByte(bytes, 0x0149, options.ramSizeCode or 0x03)
  setByte(bytes, 0x014a, options.destinationCode or 0x01)
  setByte(bytes, 0x014b, options.oldLicenseeCode or 0x33)
  setByte(bytes, 0x014c, options.version or 0x00)

  local headerChecksum = 0
  for offset = 0x0134, 0x014c do
    headerChecksum =
      (headerChecksum - bytes[offset + 1]:byte() - 1) % 0x100
  end
  setByte(bytes, 0x014d, headerChecksum)

  local globalChecksum = 0
  for offset = 0, #bytes - 1 do
    if offset ~= 0x014e and offset ~= 0x014f then
      globalChecksum =
        (globalChecksum + bytes[offset + 1]:byte()) % 0x10000
    end
  end
  setByte(bytes, 0x014e, math.floor(globalChecksum / 0x100))
  setByte(bytes, 0x014f, globalChecksum % 0x100)

  return table.concat(bytes)
end

function Cartridge.replaceByte(data, offset, value)
  return data:sub(1, offset)
    .. string.char(value)
    .. data:sub(offset + 2)
end

return Cartridge
