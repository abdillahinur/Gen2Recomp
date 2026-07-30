local Dvs = {}

local HIDDEN_POWER_TYPES = {
  "fighting",
  "flying",
  "poison",
  "ground",
  "rock",
  "bug",
  "ghost",
  "steel",
  "fire",
  "water",
  "grass",
  "electric",
  "psychic",
  "ice",
  "dragon",
  "dark",
}

local SHINY_ATTACK = {
  [2] = true,
  [3] = true,
  [6] = true,
  [7] = true,
  [10] = true,
  [11] = true,
  [14] = true,
  [15] = true,
}

local function requireDv(value, field)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < 0 or value > 15 then
    error("DVs: " .. field .. " must be an integer from 0 to 15", 3)
  end
  return value
end

function Dvs.hp(values)
  return (values.attack % 2) * 8
    + (values.defense % 2) * 4
    + (values.speed % 2) * 2
    + values.special % 2
end

function Dvs.normalize(values)
  values = values or {}
  local result = {
    attack = requireDv(values.attack or 0, "attack"),
    defense = requireDv(values.defense or 0, "defense"),
    speed = requireDv(values.speed or 0, "speed"),
    special = requireDv(values.special or 0, "special"),
  }
  result.hp = Dvs.hp(result)
  return result
end

function Dvs.gender(threshold, values)
  if threshold == 255 then return "genderless" end
  if threshold == 0 then return "male" end
  if threshold == 254 then return "female" end
  if type(threshold) ~= "number"
      or threshold % 1 ~= 0
      or threshold < 0 or threshold > 255 then
    error("DVs: gender threshold must be a byte", 2)
  end
  local combined = values.attack * 16 + values.speed
  return combined <= threshold and "female" or "male"
end

function Dvs.isShiny(values)
  return SHINY_ATTACK[values.attack] == true
    and values.defense == 10
    and values.speed == 10
    and values.special == 10
end

function Dvs.hiddenPower(values)
  local typeIndex =
    (values.attack % 4) * 4 + values.defense % 4
  local topBits =
    math.floor(values.attack / 8) * 8
    + math.floor(values.defense / 8) * 4
    + math.floor(values.speed / 8) * 2
    + math.floor(values.special / 8)
  local power = math.floor(
    (topBits * 5 + values.special % 4) / 2
  ) + 31
  return {
    type = HIDDEN_POWER_TYPES[typeIndex + 1],
    power = power,
  }
end

return Dvs
