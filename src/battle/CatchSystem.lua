local CatchSystem = {}

local function ballMultiplier(ball)
  local numerator = ball.catchRateNumerator
    or ball.catchRateModifier
    or 1
  local denominator = ball.catchRateDenominator or 1
  if type(numerator) ~= "number" or numerator % 1 ~= 0
      or numerator < 1
      or type(denominator) ~= "number" or denominator % 1 ~= 0
      or denominator < 1 then
    error("catch system: ball multiplier must be positive integers", 3)
  end
  return numerator, denominator
end

function CatchSystem.rate(target, ball)
  if ball.master then return 255 end
  local numerator, denominator = ballMultiplier(ball)
  local maximum = target.stats.hp
  local current = target.currentHP
  local rate = math.floor(
    (3 * maximum - 2 * current)
      * target.species.catchRate
      * numerator
      / denominator
      / (3 * maximum)
  )
  local status = target.status and target.status.id
  if status == "sleep" or status == "freeze" then rate = rate + 10 end
  return math.max(1, math.min(255, rate))
end

function CatchSystem.attempt(state, target, ball)
  if state.kind ~= "wild" then
    return { caught = false, reason = "trainer_battle" }
  end
  local rate = CatchSystem.rate(target, ball)
  local roll = ball.master and 0 or state.rng:nextByte()
  local caught = roll <= rate
  state:emit(caught and "battle.caught" or "battle.catch_failed", {
    speciesId = target.speciesId,
    ballId = ball.id,
    rate = rate,
    roll = roll,
  })
  if caught then
    state.outcome = "caught"
    state.phase = "complete"
  end
  return {
    caught = caught,
    rate = rate,
    roll = roll,
  }
end

return CatchSystem
