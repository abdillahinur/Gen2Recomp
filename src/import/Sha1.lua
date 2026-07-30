local Bit32 = require("src.core.Bit32")

local Sha1 = {}
Sha1.__index = Sha1

local MODULO = 0x100000000
local BLOCK_SIZE = 64

local function add(...)
  local result = 0
  for index = 1, select("#", ...) do
    result = result + select(index, ...)
  end
  return result % MODULO
end

local function packWord(value)
  return string.char(
    math.floor(value / 0x1000000) % 0x100,
    math.floor(value / 0x10000) % 0x100,
    math.floor(value / 0x100) % 0x100,
    value % 0x100
  )
end

local function processBlock(self, data, start)
  local words = {}

  for index = 0, 15 do
    local offset = start + index * 4
    local a, b, c, d = data:byte(offset, offset + 3)
    words[index] = a * 0x1000000 + b * 0x10000 + c * 0x100 + d
  end

  for index = 16, 79 do
    words[index] = Bit32.rol(Bit32.bxor(
      Bit32.bxor(words[index - 3], words[index - 8]),
      Bit32.bxor(words[index - 14], words[index - 16])
    ), 1)
  end

  local a = self.h0
  local b = self.h1
  local c = self.h2
  local d = self.h3
  local e = self.h4

  for index = 0, 79 do
    local f
    local k

    if index < 20 then
      f = Bit32.bor(
        Bit32.band(b, c),
        Bit32.band(Bit32.bnot(b), d)
      )
      k = 0x5a827999
    elseif index < 40 then
      f = Bit32.bxor(Bit32.bxor(b, c), d)
      k = 0x6ed9eba1
    elseif index < 60 then
      f = Bit32.bor(
        Bit32.bor(Bit32.band(b, c), Bit32.band(b, d)),
        Bit32.band(c, d)
      )
      k = 0x8f1bbcdc
    else
      f = Bit32.bxor(Bit32.bxor(b, c), d)
      k = 0xca62c1d6
    end

    local temporary = add(Bit32.rol(a, 5), f, e, k, words[index])
    e = d
    d = c
    c = Bit32.rol(b, 30)
    b = a
    a = temporary
  end

  self.h0 = add(self.h0, a)
  self.h1 = add(self.h1, b)
  self.h2 = add(self.h2, c)
  self.h3 = add(self.h3, d)
  self.h4 = add(self.h4, e)
end

function Sha1.new()
  return setmetatable({
    h0 = 0x67452301,
    h1 = 0xefcdab89,
    h2 = 0x98badcfe,
    h3 = 0x10325476,
    h4 = 0xc3d2e1f0,
    totalLength = 0,
    buffer = "",
    finalized = false,
    digestBytes = nil,
  }, Sha1)
end

function Sha1:update(chunk)
  if self.finalized then
    error("cannot update a finalized SHA-1 digest", 2)
  end
  if type(chunk) ~= "string" then
    error("SHA-1 chunk must be a binary string", 2)
  end
  if #chunk == 0 then
    return self
  end

  self.totalLength = self.totalLength + #chunk
  local pending = self.buffer .. chunk
  local offset = 1

  while #pending - offset + 1 >= BLOCK_SIZE do
    processBlock(self, pending, offset)
    offset = offset + BLOCK_SIZE
  end

  self.buffer = pending:sub(offset)
  return self
end

function Sha1:final()
  if self.digestBytes then
    return self.digestBytes
  end

  local bitLength = self.totalLength * 8
  local high = math.floor(bitLength / MODULO)
  local low = bitLength % MODULO
  local finalData = self.buffer .. string.char(0x80)
  local zeroCount = (56 - (#finalData % BLOCK_SIZE)) % BLOCK_SIZE
  finalData = finalData .. string.rep("\0", zeroCount)
    .. packWord(high)
    .. packWord(low)

  for offset = 1, #finalData, BLOCK_SIZE do
    processBlock(self, finalData, offset)
  end

  self.buffer = ""
  self.finalized = true
  self.digestBytes = packWord(self.h0)
    .. packWord(self.h1)
    .. packWord(self.h2)
    .. packWord(self.h3)
    .. packWord(self.h4)
  return self.digestBytes
end

function Sha1:finalHex()
  return (self:final():gsub(".", function(character)
    return ("%02x"):format(character:byte())
  end))
end

function Sha1.hex(data)
  return Sha1.new():update(data):finalHex()
end

return Sha1

