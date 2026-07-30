local BattleRng = {}
BattleRng.__index = BattleRng

local MODULUS = 2147483647

function BattleRng.new(seed)
  seed = seed or 1
  if type(seed) ~= "number" or seed % 1 ~= 0
      or seed < 0 or seed >= MODULUS then
    error("battle RNG: seed must be a 31-bit non-negative integer", 2)
  end
  return setmetatable({
    state = seed,
    draws = 0,
  }, BattleRng)
end

function BattleRng:nextByte()
  -- Park-Miller keeps the intermediate below Lua's exact 53-bit range.
  self.state = self.state * 16807 % MODULUS
  self.draws = self.draws + 1
  return self.state % 256
end

function BattleRng:range(minimum, maximum)
  if type(minimum) ~= "number" or type(maximum) ~= "number"
      or minimum % 1 ~= 0 or maximum % 1 ~= 0
      or minimum > maximum then
    error("battle RNG: range requires ordered integers", 2)
  end
  local width = maximum - minimum + 1
  return minimum + self:nextByte() % width
end

return BattleRng
