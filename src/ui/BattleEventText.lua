local BattleEventText = {}

local function speciesName(registry, id)
  local ok, record = pcall(registry.get, registry, "species", id)
  return ok and record.name or tostring(id)
end

local function activeName(state, sideId)
  local side = state[sideId]
  local pokemon = side and side:active()
  return pokemon and pokemon.nickname or sideId:upper()
end

function BattleEventText.resolve(event, session)
  local data = event.data or {}
  local state = session.state
  local registry = session.registry
  if event.kind == "battle.move_used" then
    local move = registry:get("moves", data.moveId)
    return activeName(state, data.sideId) .. " used " .. move.name .. "!"
  elseif event.kind == "battle.move_missed" then
    return "The attack missed!"
  elseif event.kind == "battle.damage" then
    if data.critical then return "A critical hit!" end
    if data.effectiveness == 0 then return "It had no effect." end
    if data.effectiveness and data.effectiveness > 1 then
      return "It's super effective!"
    elseif data.effectiveness and data.effectiveness < 1 then
      return "It's not very effective."
    end
  elseif event.kind == "battle.fainted" then
    return speciesName(registry, data.speciesId) .. " fainted!"
  elseif event.kind == "battle.switched"
      or event.kind == "battle.forced_switch" then
    return activeName(state, data.sideId) .. " entered the battle!"
  elseif event.kind == "battle.experience_gained" then
    return activeName(state, "player")
      .. " gained " .. tostring(data.amount) .. " EXP.!"
  elseif event.kind == "battle.caught" then
    return speciesName(registry, data.speciesId) .. " was caught!"
  elseif event.kind == "battle.catch_failed" then
    return "Oh no! The Pokémon broke free!"
  elseif event.kind == "battle.run_failed" then
    return data.reason == "trainer_battle"
      and "No! There's no running from a trainer battle!"
      or "Can't escape!"
  elseif event.kind == "battle.escaped" then
    return "Got away safely!"
  elseif event.kind == "battle.cannot_move" then
    return activeName(state, data.sideId) .. " can't move!"
  elseif event.kind == "battle.status_cured" then
    return activeName(state, data.sideId) .. " recovered!"
  elseif event.kind == "battle.status_inflicted" then
    return activeName(state, data.sideId)
      .. " is " .. tostring(data.status) .. "!"
  elseif event.kind == "battle.status_damage" then
    return activeName(state, data.sideId)
      .. " is hurt by " .. tostring(data.status) .. "!"
  end
  return nil
end

return BattleEventText
