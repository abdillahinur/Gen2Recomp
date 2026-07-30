local TypeChart = require("src.battle.TypeChart")

local TrainerAi = {}
TrainerAi.__index = TrainerAi

local STATUS_EFFECTS = {
  ["battle.effect.inflict_sleep"] = true,
  ["battle.effect.inflict_poison"] = true,
  ["battle.effect.inflict_toxic"] = true,
  ["battle.effect.inflict_burn"] = true,
  ["battle.effect.inflict_paralysis"] = true,
  ["battle.effect.inflict_freeze"] = true,
}

function TrainerAi.new(registry)
  if type(registry) ~= "table" or type(registry.get) ~= "function" then
    error("trainer AI: data registry is required", 2)
  end
  return setmetatable({ registry = registry }, TrainerAi)
end

function TrainerAi:_legalMoves(pokemon)
  local result = {}
  for index, slot in ipairs(pokemon.moves) do
    if slot.pp > 0 then
      result[#result + 1] = {
        index = index,
        move = self.registry:get("moves", slot.id),
      }
    end
  end
  if #result == 0 then
    error("trainer AI: active Pokemon has no usable moves", 2)
  end
  return result
end

local function smartScore(move, target)
  local score = 0
  local effectiveness =
    TypeChart.effectiveness(move.type, target.species.types)
  if effectiveness == 0 then
    score = score - 100
  elseif effectiveness >= 4 then
    score = score + 6
  elseif effectiveness >= 2 then
    score = score + 3
  elseif effectiveness < 1 then
    score = score - 2
  end
  score = score + math.floor(move.power / 40)
  if STATUS_EFFECTS[move.effectId] then
    score = score + 2
    if target.status then score = score - 8 end
  end
  if move.accuracy < 180 then score = score - 1 end
  return score
end

local function healthiestBench(side)
  local bestIndex
  local bestRatio = -1
  for index, pokemon in ipairs(side.party) do
    if index ~= side.activeIndex and not pokemon:isFainted() then
      local ratio = pokemon.currentHP / pokemon.stats.hp
      if ratio > bestRatio then
        bestRatio = ratio
        bestIndex = index
      end
    end
  end
  return bestIndex, bestRatio
end

function TrainerAi:_switchAction(side)
  local active = side:active()
  if active.currentHP * 4 >= active.stats.hp then return nil end
  local index, ratio = healthiestBench(side)
  if index and ratio > 0.5 then
    return { kind = "switch", partyIndex = index }
  end
end

function TrainerAi:chooseAction(state, profileId)
  profileId = profileId or "battle.ai.basic"
  local side = state.opponent
  if profileId ~= "battle.ai.basic" then
    local switch = self:_switchAction(side)
    if switch then return switch end
  end

  local candidates = self:_legalMoves(side:active())
  if profileId == "battle.ai.basic" then
    local selected = candidates[state.rng:range(1, #candidates)]
    return { kind = "move", moveIndex = selected.index }
  elseif profileId ~= "battle.ai.smart" then
    error("trainer AI: unknown profile " .. tostring(profileId), 2)
  end

  local target = state.player:active()
  local bestScore
  local best = {}
  for _, candidate in ipairs(candidates) do
    local score = smartScore(candidate.move, target)
    if bestScore == nil or score > bestScore then
      bestScore = score
      best = { candidate }
    elseif score == bestScore then
      best[#best + 1] = candidate
    end
  end
  local selected = best[state.rng:range(1, #best)]
  return { kind = "move", moveIndex = selected.index }
end

return TrainerAi
