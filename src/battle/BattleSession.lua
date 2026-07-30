local BattleEngine = require("src.battle.BattleEngine")
local BattleState = require("src.battle.BattleState")
local CatchSystem = require("src.battle.CatchSystem")
local DefaultEffects = require("src.battle.DefaultEffects")
local ExperienceSystem = require("src.battle.ExperienceSystem")
local TrainerAi = require("src.battle.TrainerAi")

local BattleSession = {}
BattleSession.__index = BattleSession

function BattleSession.new(registry, options)
  options = options or {}
  local state = options.state or BattleState.new(options)
  local effects = options.effectRegistry or DefaultEffects.create()
  return setmetatable({
    registry = registry,
    state = state,
    engine = BattleEngine.new(state, registry, {
      effectRegistry = effects,
      statusSystem = options.statusSystem,
    }),
    ai = options.ai or TrainerAi.new(registry),
    aiProfileId = options.aiProfileId or "battle.ai.basic",
    learnsets = options.learnsets or {},
    chooseForget = options.chooseForget,
    rewardedFaints = {},
  }, BattleSession)
end

function BattleSession:_awardExperience()
  for _, defeated in ipairs(self.state.opponent.party) do
    if defeated:isFainted() and not self.rewardedFaints[defeated] then
      self.rewardedFaints[defeated] = true
      local recipient = self.state.player:active()
      if recipient:isFainted() then
        local index = self.state.player:firstAvailable(
          self.state.player.activeIndex)
        recipient = index and self.state.player.party[index] or nil
      end
      if recipient then
        local amount = ExperienceSystem.reward(defeated, {
          trainer = self.state.kind == "trainer",
        })
        local result = ExperienceSystem.gain(
          recipient,
          amount,
          self.learnsets[recipient.speciesId],
          self.registry,
          self.chooseForget
        )
        self.state:emit("battle.experience_gained", {
          speciesId = recipient.speciesId,
          defeatedSpeciesId = defeated.speciesId,
          amount = amount,
          oldLevel = result.oldLevel,
          newLevel = result.newLevel,
          learned = result.learned,
        })
      end
    end
  end
end

function BattleSession:command(action)
  if self.state.phase == "complete" then
    error("battle session: battle is already complete", 2)
  end
  self.engine:submit("player", action)
  local opponentAction =
    self.ai:chooseAction(self.state, self.aiProfileId)
  local order = self.engine:submit("opponent", opponentAction)
  self:_awardExperience()
  return order
end

function BattleSession:catch(itemId)
  if self.state.phase == "complete" then
    error("battle session: battle is already complete", 2)
  end
  local result = CatchSystem.attempt(
    self.state,
    self.state.opponent:active(),
    self.registry:get("items", itemId)
  )
  return result
end

function BattleSession:run()
  if self.state.phase == "complete" then
    error("battle session: battle is already complete", 2)
  end
  if self.state.kind ~= "wild" then
    self.state:emit("battle.run_failed", {
      reason = "trainer_battle",
    })
    return false
  end
  self.state.outcome = "escaped"
  self.state.phase = "complete"
  self.state.pendingActions = {}
  self.state:emit("battle.escaped")
  self.state:emit("battle.ended", { outcome = "escaped" })
  return true
end

function BattleSession:runToCompletion(maximumTurns)
  maximumTurns = maximumTurns or 100
  while self.state.phase ~= "complete"
      and self.state.turn <= maximumTurns do
    local moveIndex
    for index, slot in ipairs(self.state.player:active().moves) do
      if slot.pp > 0 then
        moveIndex = index
        break
      end
    end
    if not moveIndex then
      error("battle session: player has no usable move", 2)
    end
    self:command({ kind = "move", moveIndex = moveIndex })
  end
  if self.state.phase ~= "complete" then
    error(("battle session: exceeded %d turns"):format(maximumTurns), 2)
  end
  return self.state.outcome
end

return BattleSession
