return function(test, equal, truthy)
  local BattleState = require("src.battle.BattleState")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")
  local SpeciesRecord = require("src.pokemon.SpeciesRecord")
  local StatusSystem = require("src.battle.StatusSystem")

  local function pokemon(types)
    return PokemonInstance.new(SpeciesRecord.normalize({
      id = "test",
      name = "TEST",
      stats = {
        hp = 80, attack = 60, defense = 50, speed = 40,
        specialAttack = 50, specialDefense = 50,
      },
      types = types or { "normal" },
      catchRate = 45,
      baseExperience = 64,
      growthRate = 0,
      gender = { threshold = 127 },
    }), { level = 50 })
  end

  local function state(rng, player, opponent)
    return BattleState.new({
      kind = "wild",
      rng = rng or SequenceRng.new({ 255 }),
      playerParty = { player },
      opponentParty = { opponent or pokemon() },
    })
  end

  test("major statuses enforce immunity and exclusivity", function()
    local fire = pokemon({ "fire" })
    truthy(not StatusSystem.inflict(fire, "burn"))
    truthy(StatusSystem.inflict(fire, "poison"))
    truthy(not StatusSystem.inflict(fire, "paralysis"))
    truthy(StatusSystem.cure(fire))
    equal(fire.status, nil)
  end)

  test("stat stages burn and paralysis modify battle stats", function()
    local target = pokemon()
    equal(StatusSystem.changeStage(target, "attack", 2), 2)
    equal(
      StatusSystem.modifiedStat(target, "attack"),
      target.stats.attack * 2
    )
    StatusSystem.inflict(target, "burn")
    equal(
      StatusSystem.modifiedStat(target, "attack"),
      target.stats.attack
    )
    StatusSystem.cure(target)
    StatusSystem.inflict(target, "paralysis")
    equal(
      StatusSystem.modifiedStat(target, "speed"),
      math.max(1, math.floor(target.stats.speed / 4))
    )
  end)

  test("sleep freeze flinch and paralysis gate actions", function()
    local sleeper = pokemon()
    StatusSystem.inflict(sleeper, "sleep", { turns = 2 })
    local battle = state(nil, sleeper)
    local canAct, reason =
      StatusSystem.beforeAction(battle, "player", sleeper)
    truthy(not canAct)
    equal(reason, "sleep")
    truthy(StatusSystem.beforeAction(battle, "player", sleeper))
    equal(sleeper.status, nil)

    StatusSystem.setVolatile(sleeper, "flinch")
    canAct, reason =
      StatusSystem.beforeAction(battle, "player", sleeper)
    truthy(not canAct)
    equal(reason, "flinch")
  end)

  test("poison burn and toxic apply end-turn residual damage", function()
    local poisoned = pokemon()
    StatusSystem.inflict(poisoned, "poison")
    local battle = state(nil, poisoned)
    local expected = math.max(1, math.floor(poisoned.stats.hp / 8))
    equal(
      StatusSystem.endTurn(battle, "player", poisoned),
      expected
    )

    local toxic = pokemon()
    StatusSystem.inflict(toxic, "toxic")
    battle = state(nil, toxic)
    local first = StatusSystem.endTurn(battle, "player", toxic)
    local second = StatusSystem.endTurn(battle, "player", toxic)
    truthy(second >= first * 2 - 1)
    equal(toxic.status.counter, 3)
  end)
end
