local GrowthRates = require("src.pokemon.GrowthRates")

local ExperienceSystem = {}

local function knowsMove(pokemon, moveId)
  for _, slot in ipairs(pokemon.moves) do
    if slot.id == moveId then return true end
  end
  return false
end

local function learnMove(pokemon, move, chooseForget)
  if knowsMove(pokemon, move.id) then return "already_known" end
  local slot = {
    id = move.id,
    pp = move.pp,
    maxPP = move.pp,
  }
  if #pokemon.moves < 4 then
    pokemon.moves[#pokemon.moves + 1] = slot
    return "learned"
  end
  local index = chooseForget and chooseForget(pokemon, move.id)
  if index == nil then return "declined" end
  if type(index) ~= "number" or index % 1 ~= 0
      or index < 1 or index > 4 then
    error("experience system: forget choice must be a move index", 3)
  end
  pokemon.moves[index] = slot
  return "replaced"
end

function ExperienceSystem.reward(defeated, options)
  options = options or {}
  local participants = options.participants or 1
  if type(participants) ~= "number" or participants % 1 ~= 0
      or participants < 1 then
    error("experience system: participants must be positive", 2)
  end
  local value = math.floor(
    defeated.species.baseExperience * defeated.level / 7
  )
  if options.trainer then value = math.floor(value * 3 / 2) end
  value = math.floor(value / participants)
  if options.traded then value = math.floor(value * 3 / 2) end
  return math.max(1, value)
end

function ExperienceSystem.gain(
  pokemon,
  amount,
  learnset,
  registry,
  chooseForget
)
  if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 0 then
    error("experience system: amount must be non-negative", 2)
  end
  local oldLevel = pokemon.level
  pokemon.experience = math.min(16777215, pokemon.experience + amount)
  local targetLevel = GrowthRates.levelForExperience(
    pokemon.species.growthRate,
    pokemon.experience
  )
  targetLevel = math.max(oldLevel, targetLevel)
  local learned = {}
  while pokemon.level < targetLevel do
    pokemon.level = pokemon.level + 1
    pokemon:recalculateStats()
    for _, entry in ipairs(learnset or {}) do
      if entry.level == pokemon.level then
        local result = learnMove(
          pokemon,
          registry:get("moves", entry.moveId),
          chooseForget
        )
        learned[#learned + 1] = {
          level = pokemon.level,
          moveId = entry.moveId,
          result = result,
        }
      end
    end
  end
  return {
    amount = amount,
    oldLevel = oldLevel,
    newLevel = pokemon.level,
    learned = learned,
  }
end

return ExperienceSystem
