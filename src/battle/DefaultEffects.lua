local DamageResolver = require("src.battle.DamageResolver")
local EffectRegistry = require("src.battle.EffectRegistry")
local StatusSystem = require("src.battle.StatusSystem")

local DefaultEffects = {}

local function effectOccurs(state, move, primary)
  if primary or move.effectChance == 0 then return true end
  return state.rng:nextByte() < move.effectChance
end

local function statusEffect(statusId)
  return function(state, sideId, actor, target, move)
    local result =
      DamageResolver.execute(state, sideId, actor, target, move)
    if result.hit and not target:isFainted()
        and effectOccurs(state, move, move.power == 0)
        and StatusSystem.inflict(target, statusId, {
          turns = statusId == "sleep"
            and state.rng:range(1, 7) or nil,
        }) then
      state:emit("battle.status_inflicted", {
        sideId = sideId == "player" and "opponent" or "player",
        status = statusId,
      })
      result.effectApplied = true
    end
    return result
  end
end

local function stageEffect(stat, amount, targetSelf)
  return function(state, sideId, actor, target, move)
    local result =
      DamageResolver.execute(state, sideId, actor, target, move)
    local recipient = targetSelf and actor or target
    if result.hit and not recipient:isFainted()
        and effectOccurs(state, move, move.power == 0) then
      local changed =
        StatusSystem.changeStage(recipient, stat, amount)
      state:emit("battle.stat_stage_changed", {
        sideId = targetSelf
          and sideId
          or (sideId == "player" and "opponent" or "player"),
        stat = stat,
        amount = changed,
      })
      result.effectApplied = changed ~= 0
    end
    return result
  end
end

function DefaultEffects.create()
  local registry = EffectRegistry.new()
  registry:register("battle.effect.none", DamageResolver.execute)

  for _, statusId in ipairs({
    "sleep",
    "poison",
    "toxic",
    "burn",
    "paralysis",
    "freeze",
  }) do
    registry:register(
      "battle.effect.inflict_" .. statusId,
      statusEffect(statusId)
    )
  end

  for _, stat in ipairs({
    "attack",
    "defense",
    "speed",
    "specialAttack",
    "specialDefense",
    "accuracy",
    "evasion",
  }) do
    registry:register(
      "battle.effect.raise_" .. stat,
      stageEffect(stat, 1, true)
    )
    registry:register(
      "battle.effect.lower_" .. stat,
      stageEffect(stat, -1, false)
    )
  end

  registry:register("battle.effect.drain", function(
    state, sideId, actor, target, move
  )
    local result =
      DamageResolver.execute(state, sideId, actor, target, move)
    if result.appliedDamage and result.appliedDamage > 0 then
      local healed = actor:heal(
        math.max(1, math.floor(result.appliedDamage / 2))
      )
      state:emit("battle.drain", {
        sideId = sideId,
        healing = healed,
      })
    end
    return result
  end)

  registry:register("battle.effect.recoil", function(
    state, sideId, actor, target, move
  )
    local result =
      DamageResolver.execute(state, sideId, actor, target, move)
    if result.appliedDamage and result.appliedDamage > 0 then
      local recoil = actor:damage(
        math.max(1, math.floor(result.appliedDamage / 4))
      )
      state:emit("battle.recoil", {
        sideId = sideId,
        damage = recoil,
      })
    end
    return result
  end)

  registry:register("battle.effect.flinch", function(
    state, sideId, actor, target, move
  )
    local result =
      DamageResolver.execute(state, sideId, actor, target, move)
    if result.hit and not target:isFainted()
        and effectOccurs(state, move, false) then
      StatusSystem.setVolatile(target, "flinch")
      result.effectApplied = true
    end
    return result
  end)
  return registry
end

return DefaultEffects
