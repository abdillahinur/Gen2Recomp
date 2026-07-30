local Rom = {}
Rom.__index = Rom

local ROM_BANK_SIZE = 0x4000
local FIXED_BANK_START = 0x0000
local FIXED_BANK_END = 0x3fff
local SWITCHABLE_BANK_START = 0x4000
local SWITCHABLE_BANK_END = 0x7fff

local function requireInteger(name, value, minimum)
  if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
    error(name .. " must be an integer", 3)
  end
  if minimum and value < minimum then
    error(name .. " must be at least " .. minimum, 3)
  end
  return value
end

local function normalizeData(data)
  if type(data) == "string" then
    return data
  end

  local kind = type(data)
  if (kind == "table" or kind == "userdata")
      and type(data.getString) == "function" then
    local value = data:getString()
    if type(value) ~= "string" then
      error("ROM data getString() must return a string", 3)
    end
    return value
  end

  error("ROM data must be a binary string or expose getString()", 3)
end

function Rom.new(data)
  local bytes = normalizeData(data)
  return setmetatable({
    data = bytes,
    length = #bytes,
  }, Rom)
end

function Rom:size()
  return self.length
end

function Rom:bankCount()
  if self.length == 0 then
    return 0
  end
  return math.ceil(self.length / ROM_BANK_SIZE)
end

function Rom:assertRange(offset, length)
  requireInteger("offset", offset, 0)
  requireInteger("length", length, 0)

  if offset > self.length or length > self.length - offset then
    error(("ROM range out of bounds: offset=0x%X length=0x%X size=0x%X")
      :format(offset, length, self.length), 2)
  end
end

function Rom:readByte(offset)
  self:assertRange(offset, 1)
  return self.data:byte(offset + 1)
end

function Rom:readString(offset, length)
  self:assertRange(offset, length)
  if length == 0 then
    return ""
  end
  return self.data:sub(offset + 1, offset + length)
end

function Rom:readBytes(offset, length)
  local raw = self:readString(offset, length)
  local result = {}
  for index = 1, #raw do
    result[index] = raw:byte(index)
  end
  return result
end

function Rom:readWord(offset)
  self:assertRange(offset, 2)
  local low, high = self.data:byte(offset + 1, offset + 2)
  return low + high * 0x100
end

function Rom:offset(bank, address, length)
  requireInteger("bank", bank, 0)
  requireInteger("address", address, 0)
  length = length == nil and 1 or requireInteger("length", length, 0)

  local physical
  local windowEnd

  if bank == 0 then
    if address < FIXED_BANK_START or address > FIXED_BANK_END then
      error(("bank 0 address must be between 0x%04X and 0x%04X")
        :format(FIXED_BANK_START, FIXED_BANK_END), 2)
    end
    physical = address
    windowEnd = FIXED_BANK_END
  else
    if address < SWITCHABLE_BANK_START or address > SWITCHABLE_BANK_END then
      error(("bank %d address must be between 0x%04X and 0x%04X")
        :format(bank, SWITCHABLE_BANK_START, SWITCHABLE_BANK_END), 2)
    end
    physical = bank * ROM_BANK_SIZE + address - SWITCHABLE_BANK_START
    windowEnd = SWITCHABLE_BANK_END
  end

  if length > windowEnd - address + 1 then
    error(("banked range crosses the 0x%04X address-window boundary")
      :format(windowEnd), 2)
  end

  self:assertRange(physical, length)
  return physical
end

function Rom:byte(bank, address)
  return self:readByte(self:offset(bank, address, 1))
end

function Rom:string(bank, address, length)
  return self:readString(self:offset(bank, address, length), length)
end

function Rom:bytes(bank, address, length)
  return self:readBytes(self:offset(bank, address, length), length)
end

function Rom:word(bank, address)
  return self:readWord(self:offset(bank, address, 2))
end

Rom.BANK_SIZE = ROM_BANK_SIZE

return Rom

