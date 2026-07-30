local SequenceRng = {}
SequenceRng.__index = SequenceRng

function SequenceRng.new(values)
  if type(values) ~= "table" or #values == 0 then
    error("sequence RNG: at least one byte is required", 2)
  end
  local bytes = {}
  for index, value in ipairs(values) do
    if type(value) ~= "number" or value % 1 ~= 0
        or value < 0 or value > 255 then
      error("sequence RNG: values must be bytes", 2)
    end
    bytes[index] = value
  end
  return setmetatable({
    values = bytes,
    index = 1,
    draws = 0,
  }, SequenceRng)
end

function SequenceRng:nextByte()
  local value = self.values[self.index]
  self.index = self.index % #self.values + 1
  self.draws = self.draws + 1
  return value
end

function SequenceRng:range(minimum, maximum)
  return minimum + self:nextByte() % (maximum - minimum + 1)
end

return SequenceRng
