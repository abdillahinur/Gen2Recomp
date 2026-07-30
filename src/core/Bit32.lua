local Bit32 = {}

local MODULO = 0x100000000
local MASK = 0xffffffff

local function unsigned(value)
  return value % MODULO
end

local hasNative, native = pcall(require, "bit")

if hasNative then
  function Bit32.band(a, b)
    return unsigned(native.band(a, b))
  end

  function Bit32.bor(a, b)
    return unsigned(native.bor(a, b))
  end

  function Bit32.bxor(a, b)
    return unsigned(native.bxor(a, b))
  end

  function Bit32.bnot(value)
    return unsigned(native.bnot(value))
  end

  function Bit32.lshift(value, count)
    return unsigned(native.lshift(value, count))
  end

  function Bit32.rshift(value, count)
    return unsigned(native.rshift(value, count))
  end

  function Bit32.rol(value, count)
    return unsigned(native.rol(value, count))
  end
else
  local function binary(a, b, operation)
    a = unsigned(a)
    b = unsigned(b)
    local result = 0
    local place = 1

    for _ = 1, 32 do
      local aBit = a % 2
      local bBit = b % 2
      if operation(aBit, bBit) then
        result = result + place
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      place = place * 2
    end

    return result
  end

  function Bit32.band(a, b)
    return binary(a, b, function(aBit, bBit)
      return aBit == 1 and bBit == 1
    end)
  end

  function Bit32.bor(a, b)
    return binary(a, b, function(aBit, bBit)
      return aBit == 1 or bBit == 1
    end)
  end

  function Bit32.bxor(a, b)
    return binary(a, b, function(aBit, bBit)
      return aBit ~= bBit
    end)
  end

  function Bit32.bnot(value)
    return MASK - unsigned(value)
  end

  function Bit32.lshift(value, count)
    count = count % 32
    return unsigned(unsigned(value) * 2 ^ count)
  end

  function Bit32.rshift(value, count)
    count = count % 32
    return math.floor(unsigned(value) / 2 ^ count)
  end

  function Bit32.rol(value, count)
    count = count % 32
    if count == 0 then
      return unsigned(value)
    end
    return unsigned(
      Bit32.lshift(value, count) + Bit32.rshift(value, 32 - count)
    )
  end
end

Bit32.unsigned = unsigned

return Bit32

