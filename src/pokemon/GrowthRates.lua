local GrowthRates = {}

local function requireLevel(level)
  if type(level) ~= "number" or level % 1 ~= 0
      or level < 1 or level > 100 then
    error("growth rates: level must be an integer from 1 to 100", 3)
  end
end

function GrowthRates.atLevel(growthRate, level)
  requireLevel(level)
  local cube = level * level * level
  local square = level * level
  local experience
  if growthRate == 0 then
    experience = cube
  elseif growthRate == 1 then
    experience = math.floor(3 * cube / 4) + 10 * square - 30
  elseif growthRate == 2 then
    experience = math.floor(3 * cube / 4) + 20 * square - 70
  elseif growthRate == 3 then
    experience =
      math.floor(6 * cube / 5) - 15 * square + 100 * level - 140
  elseif growthRate == 4 then
    experience = math.floor(4 * cube / 5)
  elseif growthRate == 5 then
    experience = math.floor(5 * cube / 4)
  else
    error("growth rates: unknown growth rate " .. tostring(growthRate), 2)
  end
  return math.max(0, experience)
end

function GrowthRates.levelForExperience(growthRate, experience)
  if type(experience) ~= "number" or experience % 1 ~= 0
      or experience < 0 then
    error("growth rates: experience must be non-negative", 2)
  end
  local level = 1
  while level < 100
      and experience >= GrowthRates.atLevel(growthRate, level + 1) do
    level = level + 1
  end
  return level
end

return GrowthRates
