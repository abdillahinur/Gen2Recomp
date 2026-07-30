local TypeChart = {}

local SPECIAL = {
  fire = true,
  water = true,
  grass = true,
  electric = true,
  psychic = true,
  ice = true,
  dragon = true,
  dark = true,
}

local SUPER = {
  fire = { grass = true, ice = true, bug = true, steel = true },
  water = { fire = true, ground = true, rock = true },
  electric = { water = true, flying = true },
  grass = { water = true, ground = true, rock = true },
  ice = {
    grass = true, ground = true, flying = true, dragon = true,
  },
  fighting = {
    normal = true, ice = true, rock = true, dark = true, steel = true,
  },
  poison = { grass = true },
  ground = {
    fire = true, electric = true, poison = true,
    rock = true, steel = true,
  },
  flying = { grass = true, fighting = true, bug = true },
  psychic = { fighting = true, poison = true },
  bug = { grass = true, psychic = true, dark = true },
  rock = { fire = true, ice = true, flying = true, bug = true },
  ghost = { psychic = true, ghost = true },
  dragon = { dragon = true },
  dark = { psychic = true, ghost = true },
  steel = { ice = true, rock = true },
}

local RESIST = {
  normal = { rock = true, steel = true },
  fire = {
    fire = true, water = true, rock = true, dragon = true,
  },
  water = { water = true, grass = true, dragon = true },
  electric = {
    electric = true, grass = true, dragon = true,
  },
  grass = {
    fire = true, grass = true, poison = true, flying = true,
    bug = true, dragon = true, steel = true,
  },
  ice = { water = true, ice = true, steel = true, fire = true },
  fighting = {
    poison = true, flying = true, psychic = true, bug = true,
  },
  poison = {
    poison = true, ground = true, rock = true, ghost = true,
  },
  ground = { grass = true, bug = true },
  flying = { electric = true, rock = true, steel = true },
  psychic = { psychic = true, steel = true },
  bug = {
    fire = true, fighting = true, poison = true, flying = true,
    ghost = true, steel = true,
  },
  rock = { fighting = true, ground = true, steel = true },
  ghost = { dark = true, steel = true },
  dragon = { steel = true },
  dark = { fighting = true, dark = true, steel = true },
  steel = {
    fire = true, water = true, electric = true, steel = true,
  },
}

local IMMUNE = {
  electric = { ground = true },
  poison = { steel = true },
  ground = { flying = true },
  psychic = { dark = true },
  ghost = { normal = true },
  normal = { ghost = true },
  fighting = { ghost = true },
}

function TypeChart.isSpecial(moveType)
  return SPECIAL[moveType] == true
end

function TypeChart.single(moveType, defenderType)
  if IMMUNE[moveType] and IMMUNE[moveType][defenderType] then return 0 end
  if SUPER[moveType] and SUPER[moveType][defenderType] then return 2 end
  if RESIST[moveType] and RESIST[moveType][defenderType] then return 0.5 end
  return 1
end

function TypeChart.effectiveness(moveType, defenderTypes)
  local result = 1
  local seen = {}
  for _, defenderType in ipairs(defenderTypes or {}) do
    if not seen[defenderType] then
      result = result * TypeChart.single(moveType, defenderType)
      seen[defenderType] = true
    end
  end
  return result
end

return TypeChart
