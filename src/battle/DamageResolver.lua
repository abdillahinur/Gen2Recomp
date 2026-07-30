local StatusSystem = require("src.battle.StatusSystem")
local TypeChart = require("src.battle.TypeChart")

local DamageResolver = {}

local CRITICAL_THRESHOLDS = { 17, 32, 64, 85, 128, 128, 128 }

local function contains(values, target)
  for _, value in ipairs(values or {}) do
    if value == target then return true end
  end
  return false
end

local function rotatedRight(byte)
  return math.floor(byte / 2) + (byte % 2) * 128
end

local function damageVariation(rng)
  while true do
    local value = rotatedRight(rng:nextByte())
    if value >= 217 then return value end
  end
end

local function criticalHit(rng, level)
  level = math.max(0, math.min(6, level or 0))
  return rng:nextByte() < CRITICAL_THRESHOLDS[level + 1]
end

local function calculateBase(actor, target, move, critical)
  local special = TypeChart.isSpecial(move.type)
  local attackStat = special and "specialAttack" or "attack"
  local defenseStat = special and "specialDefense" or "defense"
  local attack = critical
    and actor.stats[attackStat]
    or StatusSystem.modifiedStat(actor, attackStat)
  local defense = critical
    and target.stats[defenseStat]
    or StatusSystem.modifiedStat(target, defenseStat)
  defense = math.max(1, defense)
  local damage = math.floor(actor.level * 2 / 5) + 2
  damage = damage * move.power
  damage = damage * attack
  damage = math.floor(damage / defense)
  damage = math.floor(damage / 50)
  if critical then damage = math.min(65535, damage * 2) end
  return math.min(999, math.min(997, damage) + 2)
end

function DamageResolver.calculate(state, actor, target, move)
  if move.power == 0 then
    return {
      hit = true,
      damage = 0,
      critical = false,
      effectiveness = 1,
      statusMove = true,
    }
  end

  local critical = criticalHit(
    state.rng,
    move.criticalLevel or 0
  )
  local damage = calculateBase(actor, target, move, critical)
  local stab = contains(actor.species.types, move.type)
  if stab then damage = math.floor(damage * 3 / 2) end
  local effectiveness =
    TypeChart.effectiveness(move.type, target.species.types)
  damage = math.floor(damage * effectiveness)
  local variation = damage >= 2 and damageVariation(state.rng) or 255
  if damage >= 2 then
    damage = math.floor(damage * variation / 255)
  end

  local accuracyByte = move.accuracy
  local hit = accuracyByte == 255
    or state.rng:nextByte() < accuracyByte
  if effectiveness == 0 then hit = false end
  if not hit then damage = 0 end
  return {
    hit = hit,
    damage = damage,
    critical = critical,
    stab = stab,
    effectiveness = effectiveness,
    variation = variation,
    statusMove = false,
  }
end

function DamageResolver.execute(state, sideId, actor, target, move)
  local result = DamageResolver.calculate(state, actor, target, move)
  if not result.hit then
    state:emit("battle.move_missed", {
      sideId = sideId,
      moveId = move.id,
      effectiveness = result.effectiveness,
    })
    return result
  end
  if result.damage > 0 then
    result.appliedDamage = target:damage(result.damage)
    state:emit("battle.damage", {
      sideId = sideId,
      moveId = move.id,
      damage = result.appliedDamage,
      critical = result.critical,
      effectiveness = result.effectiveness,
    })
    if target:isFainted() then
      state:emit("battle.fainted", {
        sideId = sideId == "player" and "opponent" or "player",
        speciesId = target.speciesId,
      })
    end
  end
  return result
end

return DamageResolver
