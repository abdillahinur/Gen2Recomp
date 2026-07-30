local Dvs = require("src.pokemon.Dvs")
local StatCalculator = require("src.pokemon.StatCalculator")

local PokemonInstance = {}
PokemonInstance.__index = PokemonInstance

local function requireInteger(value, minimum, maximum, field)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < minimum or value > maximum then
    error(("Pokemon instance: %s must be an integer from %d to %d")
      :format(field, minimum, maximum), 3)
  end
end

local function copy(values)
  local result = {}
  for key, value in pairs(values or {}) do result[key] = value end
  return result
end

local function moveSlots(values)
  if type(values) ~= "table" or #values > 4 then
    error("Pokemon instance: moves must contain at most four slots", 3)
  end
  local result = {}
  for index, source in ipairs(values) do
    if type(source) ~= "table"
        or type(source.id) ~= "string"
        or source.id == "" then
      error("Pokemon instance: move slot requires an id", 3)
    end
    local maximum = source.maxPP or source.pp
    requireInteger(maximum, 1, 63, "move maxPP")
    local current = source.pp or maximum
    requireInteger(current, 0, maximum, "move PP")
    result[index] = {
      id = source.id,
      pp = current,
      maxPP = maximum,
    }
  end
  return result
end

function PokemonInstance.new(species, options)
  options = options or {}
  if type(species) ~= "table" or type(species.id) ~= "string" then
    error("Pokemon instance: normalized species is required", 2)
  end
  local level = options.level or 1
  requireInteger(level, 1, 100, "level")
  local self = setmetatable({
    species = species,
    speciesId = species.id,
    nickname = options.nickname or species.name,
    level = level,
    experience = options.experience or 0,
    dvs = Dvs.normalize(options.dvs),
    statExperience = copy(options.statExperience or {}),
    moves = moveSlots(options.moves or {}),
    heldItemId = options.heldItemId,
    status = nil,
    volatile = {},
  }, PokemonInstance)
  requireInteger(self.experience, 0, 16777215, "experience")
  self:recalculateStats()
  self.gender = Dvs.gender(species.gender.threshold, self.dvs)
  self.shiny = Dvs.isShiny(self.dvs)
  self.hiddenPower = Dvs.hiddenPower(self.dvs)
  self.currentHP = options.currentHP or self.stats.hp
  requireInteger(self.currentHP, 0, self.stats.hp, "currentHP")
  return self
end

function PokemonInstance:recalculateStats()
  local oldMaximum = self.stats and self.stats.hp
  self.stats = StatCalculator.calculate(
    self.species,
    self.level,
    self.dvs,
    self.statExperience
  )
  if oldMaximum and self.currentHP then
    self.currentHP = math.min(
      self.stats.hp,
      self.currentHP + self.stats.hp - oldMaximum
    )
  end
  return self.stats
end

function PokemonInstance:isFainted()
  return self.currentHP <= 0
end

function PokemonInstance:damage(amount)
  requireInteger(amount, 0, 65535, "damage")
  local applied = math.min(self.currentHP, amount)
  self.currentHP = self.currentHP - applied
  return applied
end

function PokemonInstance:heal(amount)
  requireInteger(amount, 0, 65535, "healing")
  local applied = math.min(self.stats.hp - self.currentHP, amount)
  self.currentHP = self.currentHP + applied
  return applied
end

function PokemonInstance:restore()
  self.currentHP = self.stats.hp
  self.status = nil
  for _, move in ipairs(self.moves) do move.pp = move.maxPP end
end

return PokemonInstance
