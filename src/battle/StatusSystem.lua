local StatusSystem = {}

local MAJOR = {
  sleep = true,
  poison = true,
  toxic = true,
  burn = true,
  paralysis = true,
  freeze = true,
}

local function hasType(pokemon, typeId)
  for _, value in ipairs(pokemon.species.types) do
    if value == typeId then return true end
  end
  return false
end

local function ensureVolatile(pokemon)
  pokemon.volatile = pokemon.volatile or {}
  pokemon.volatile.stages = pokemon.volatile.stages or {
    attack = 0,
    defense = 0,
    speed = 0,
    specialAttack = 0,
    specialDefense = 0,
    accuracy = 0,
    evasion = 0,
  }
  return pokemon.volatile
end

function StatusSystem.canInflict(pokemon, statusId)
  if not MAJOR[statusId] then
    error("status system: unknown major status " .. tostring(statusId), 2)
  end
  if pokemon.status or pokemon:isFainted() then return false end
  if statusId == "burn" and hasType(pokemon, "fire") then return false end
  if (statusId == "poison" or statusId == "toxic")
      and (hasType(pokemon, "poison") or hasType(pokemon, "steel")) then
    return false
  end
  if statusId == "freeze" and hasType(pokemon, "ice") then return false end
  return true
end

function StatusSystem.inflict(pokemon, statusId, options)
  options = options or {}
  if not StatusSystem.canInflict(pokemon, statusId) then return false end
  local status = { id = statusId }
  if statusId == "sleep" then
    local turns = options.turns or 1
    if type(turns) ~= "number" or turns % 1 ~= 0
        or turns < 1 or turns > 7 then
      error("status system: sleep turns must be from 1 to 7", 2)
    end
    status.turns = turns
  elseif statusId == "toxic" then
    status.counter = 1
  end
  pokemon.status = status
  return true
end

function StatusSystem.cure(pokemon)
  local previous = pokemon.status
  pokemon.status = nil
  return previous ~= nil
end

function StatusSystem.setVolatile(pokemon, id, value)
  local volatile = ensureVolatile(pokemon)
  volatile[id] = value == nil and true or value
end

function StatusSystem.clearVolatile(pokemon)
  pokemon.volatile = {}
  ensureVolatile(pokemon)
end

function StatusSystem.changeStage(pokemon, stat, amount)
  local stages = ensureVolatile(pokemon).stages
  if stages[stat] == nil then
    error("status system: unknown stat stage " .. tostring(stat), 2)
  end
  if type(amount) ~= "number" or amount % 1 ~= 0 then
    error("status system: stage amount must be an integer", 2)
  end
  local previous = stages[stat]
  stages[stat] = math.max(-6, math.min(6, previous + amount))
  return stages[stat] - previous
end

function StatusSystem.modifiedStat(pokemon, stat)
  local value = pokemon.stats[stat]
  if not value then
    error("status system: unknown battle stat " .. tostring(stat), 2)
  end
  local stage = ensureVolatile(pokemon).stages[stat] or 0
  if stage >= 0 then
    value = math.floor(value * (2 + stage) / 2)
  else
    value = math.floor(value * 2 / (2 - stage))
  end
  if stat == "attack" and pokemon.status
      and pokemon.status.id == "burn" then
    value = math.floor(value / 2)
  elseif stat == "speed" and pokemon.status
      and pokemon.status.id == "paralysis" then
    value = math.floor(value / 4)
  end
  return math.max(1, value)
end

function StatusSystem.beforeAction(state, sideId, pokemon)
  local volatile = ensureVolatile(pokemon)
  if volatile.flinch then
    volatile.flinch = nil
    state:emit("battle.cannot_move", {
      sideId = sideId,
      reason = "flinch",
    })
    return false, "flinch"
  end

  local status = pokemon.status
  if status and status.id == "sleep" then
    status.turns = status.turns - 1
    if status.turns <= 0 then
      pokemon.status = nil
      state:emit("battle.status_cured", {
        sideId = sideId,
        status = "sleep",
      })
    else
      state:emit("battle.cannot_move", {
        sideId = sideId,
        reason = "sleep",
      })
      return false, "sleep"
    end
  elseif status and status.id == "freeze" then
    state:emit("battle.cannot_move", {
      sideId = sideId,
      reason = "freeze",
    })
    return false, "freeze"
  elseif status and status.id == "paralysis"
      and state.rng:nextByte() < 64 then
    state:emit("battle.cannot_move", {
      sideId = sideId,
      reason = "paralysis",
    })
    return false, "paralysis"
  end

  if volatile.confusion then
    volatile.confusion = volatile.confusion - 1
    if volatile.confusion <= 0 then
      volatile.confusion = nil
      state:emit("battle.confusion_ended", { sideId = sideId })
    elseif state.rng:nextByte() < 128 then
      state:emit("battle.cannot_move", {
        sideId = sideId,
        reason = "confusion",
      })
      return false, "confusion"
    end
  end
  return true
end

local function residualAmount(pokemon)
  local status = pokemon.status
  if not status then return 0 end
  if status.id == "poison" or status.id == "burn" then
    return math.max(1, math.floor(pokemon.stats.hp / 8))
  elseif status.id == "toxic" then
    local amount = math.max(
      1,
      math.floor(pokemon.stats.hp * status.counter / 16)
    )
    status.counter = math.min(15, status.counter + 1)
    return amount
  end
  return 0
end

function StatusSystem.endTurn(state, sideId, pokemon)
  local amount = residualAmount(pokemon)
  if amount == 0 or pokemon:isFainted() then return 0 end
  local applied = pokemon:damage(amount)
  state:emit("battle.status_damage", {
    sideId = sideId,
    status = pokemon.status.id,
    damage = applied,
  })
  if pokemon:isFainted() then
    state:emit("battle.fainted", {
      sideId = sideId,
      speciesId = pokemon.speciesId,
    })
  end
  return applied
end

return StatusSystem
