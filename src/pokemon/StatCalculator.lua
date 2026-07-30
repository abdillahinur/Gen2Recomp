local StatCalculator = {}

local NON_HP_STATS = {
  attack = "attack",
  defense = "defense",
  speed = "speed",
  specialAttack = "special",
  specialDefense = "special",
}

local function requireInteger(value, minimum, maximum, field)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < minimum or value > maximum then
    error(("stat calculator: %s must be an integer from %d to %d")
      :format(field, minimum, maximum), 3)
  end
end

local function effortBonus(statExperience)
  return math.floor(math.sqrt(statExperience)) / 4
end

local function calculate(base, dv, statExperience, level)
  return math.floor(
    ((base + dv) * 2 + effortBonus(statExperience))
      * level / 100
  )
end

function StatCalculator.calculate(species, level, dvs, statExperience)
  requireInteger(level, 1, 100, "level")
  statExperience = statExperience or {}
  local result = {}
  local hpDv = dvs.hp or 0
  requireInteger(hpDv, 0, 15, "HP DV")
  local hpExperience = statExperience.hp or 0
  requireInteger(hpExperience, 0, 65535, "HP stat experience")
  result.hp = calculate(
    species.stats.hp,
    hpDv,
    hpExperience,
    level
  ) + level + 10

  for stat, dvName in pairs(NON_HP_STATS) do
    local dv = dvs[dvName] or 0
    local experience = statExperience[stat] or 0
    requireInteger(dv, 0, 15, stat .. " DV")
    requireInteger(
      experience, 0, 65535, stat .. " stat experience")
    result[stat] = calculate(
      species.stats[stat],
      dv,
      experience,
      level
    ) + 5
  end
  return result
end

return StatCalculator
