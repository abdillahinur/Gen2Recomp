return function(test, equal, truthy)
  local BattleState = require("src.battle.BattleState")
  local DamageResolver = require("src.battle.DamageResolver")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")
  local TypeChart = require("src.battle.TypeChart")

  local function registry()
    local species = {}
    for _, entry in ipairs({
      { "normal_mon", { "normal" } },
      { "fire_mon", { "fire" } },
      { "grass_bug", { "grass", "bug" } },
      { "ground_mon", { "ground" } },
    }) do
      species[#species + 1] = {
        id = entry[1],
        name = entry[1],
        stats = {
          hp = 50, attack = 50, defense = 50, speed = 50,
          specialAttack = 50, specialDefense = 50,
        },
        types = entry[2],
        catchRate = 45,
        baseExperience = 64,
        growthRate = 0,
        gender = { threshold = 127 },
      }
    end
    return DataRegistry.new({
      species = species,
      moves = {
        {
          id = "tackle", name = "TACKLE", type = "normal",
          power = 40, accuracy = 242, pp = 35,
        },
        {
          id = "ember", name = "EMBER", type = "fire",
          power = 40, accuracy = 255, pp = 25,
        },
        {
          id = "thunder_shock", name = "THUNDER SHOCK",
          type = "electric", power = 40, accuracy = 255, pp = 30,
        },
      },
    })
  end

  local function mon(records, id, moveId)
    local move = records:get("moves", moveId)
    return PokemonInstance.new(records:get("species", id), {
      level = 5,
      moves = { { id = moveId, pp = move.pp } },
    })
  end

  local function stateWith(rng, records, player, opponent)
    return BattleState.new({
      kind = "wild",
      rng = rng,
      playerParty = { player },
      opponentParty = { opponent },
    })
  end

  test("Gen 2 type chart handles dual weakness and immunity", function()
    equal(TypeChart.effectiveness("fire", { "grass", "bug" }), 4)
    equal(TypeChart.effectiveness("electric", { "ground" }), 0)
    equal(TypeChart.effectiveness("normal", { "rock" }), 0.5)
    truthy(TypeChart.isSpecial("fire"))
    truthy(not TypeChart.isSpecial("normal"))
  end)

  test("damage applies integer formula STAB variation and criticals",
    function()
      local records = registry()
      local actor = mon(records, "normal_mon", "tackle")
      local target = mon(records, "normal_mon", "tackle")
      local ordinary = stateWith(
        SequenceRng.new({ 255, 255, 0 }),
        records,
        actor,
        target
      )
      local result = DamageResolver.calculate(
        ordinary, actor, target, records:get("moves", "tackle"))
      equal(result.damage, 7)
      truthy(result.hit)
      truthy(result.stab)
      truthy(not result.critical)

      local critical = stateWith(
        SequenceRng.new({ 0, 255, 0 }),
        records,
        actor,
        target
      )
      result = DamageResolver.calculate(
        critical, actor, target, records:get("moves", "tackle"))
      equal(result.damage, 12)
      truthy(result.critical)
    end)

  test("accuracy misses and type immunity produce zero damage", function()
    local records = registry()
    local actor = mon(records, "normal_mon", "tackle")
    local target = mon(records, "normal_mon", "tackle")
    local missed = stateWith(
      SequenceRng.new({ 255, 255, 250 }),
      records,
      actor,
      target
    )
    local result = DamageResolver.execute(
      missed, "player", actor, target, records:get("moves", "tackle"))
    truthy(not result.hit)
    equal(target.currentHP, target.stats.hp)

    local electric = mon(records, "normal_mon", "thunder_shock")
    local ground = mon(records, "ground_mon", "tackle")
    local immune = stateWith(
      SequenceRng.new({ 255 }),
      records,
      electric,
      ground
    )
    result = DamageResolver.execute(
      immune,
      "player",
      electric,
      ground,
      records:get("moves", "thunder_shock")
    )
    truthy(not result.hit)
    equal(result.effectiveness, 0)
  end)
end
