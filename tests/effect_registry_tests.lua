return function(test, equal, truthy, raises)
  local BattleState = require("src.battle.BattleState")
  local DefaultEffects = require("src.battle.DefaultEffects")
  local EffectRegistry = require("src.battle.EffectRegistry")
  local MoveRecord = require("src.pokemon.MoveRecord")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")
  local SpeciesRecord = require("src.pokemon.SpeciesRecord")

  local function mon()
    return PokemonInstance.new(SpeciesRecord.normalize({
      id = "test",
      name = "TEST",
      stats = {
        hp = 50, attack = 50, defense = 50, speed = 50,
        specialAttack = 50, specialDefense = 50,
      },
      types = { "normal" },
      catchRate = 45,
      baseExperience = 64,
      growthRate = 0,
      gender = { threshold = 127 },
    }), { level = 5 })
  end

  local function state(rng, actor, target)
    return BattleState.new({
      kind = "wild",
      rng = rng,
      playerParty = { actor },
      opponentParty = { target },
    })
  end

  local function move(values)
    values.name = values.name or values.id
    values.type = values.type or "normal"
    values.pp = values.pp or 10
    values.priority = values.priority or 0
    return MoveRecord.normalize(values)
  end

  test("effect registry rejects duplicate and unknown effects", function()
    local registry = EffectRegistry.new()
    registry:register("test.effect", function() return true end)
    raises(function()
      registry:register("test.effect", function() end)
    end, "duplicate")
    raises(function()
      registry:execute({}, "player", {}, {}, {
        effectId = "missing",
      })
    end, "unknown")
  end)

  test("default effects inflict status and change stat stages", function()
    local actor, target = mon(), mon()
    local registry = DefaultEffects.create()
    local battle = state(SequenceRng.new({ 0 }), actor, target)
    local poison = move({
      id = "poison_powder",
      power = 0,
      accuracy = 191,
      effectId = "battle.effect.inflict_poison",
    })
    local result =
      registry:execute(battle, "player", actor, target, poison)
    truthy(result.hit)
    truthy(result.effectApplied)
    equal(target.status.id, "poison")

    local growl = move({
      id = "growl",
      power = 0,
      accuracy = 255,
      effectId = "battle.effect.lower_attack",
    })
    result = registry:execute(battle, "player", actor, target, growl)
    truthy(result.effectApplied)
    equal(target.volatile.stages.attack, -1)
  end)

  test("drain and recoil effects use applied deterministic damage", function()
    local registry = DefaultEffects.create()
    local actor, target = mon(), mon()
    actor:damage(5)
    local battle =
      state(SequenceRng.new({ 255, 255 }), actor, target)
    local drain = move({
      id = "absorb",
      type = "grass",
      power = 40,
      accuracy = 255,
      effectId = "battle.effect.drain",
    })
    local before = actor.currentHP
    local result =
      registry:execute(battle, "player", actor, target, drain)
    truthy(result.appliedDamage > 0)
    truthy(actor.currentHP > before)

    actor, target = mon(), mon()
    battle = state(SequenceRng.new({ 255, 255 }), actor, target)
    local recoil = move({
      id = "take_down",
      power = 90,
      accuracy = 255,
      effectId = "battle.effect.recoil",
    })
    result = registry:execute(
      battle, "player", actor, target, recoil)
    truthy(result.appliedDamage > 0)
    truthy(actor.currentHP < actor.stats.hp)
  end)
end
