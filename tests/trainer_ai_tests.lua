return function(test, equal)
  local BattleState = require("src.battle.BattleState")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")
  local TrainerAi = require("src.battle.TrainerAi")

  local function registry()
    local function species(id, types)
      return {
        id = id, name = id,
        stats = {
          hp = 50, attack = 50, defense = 50, speed = 50,
          specialAttack = 50, specialDefense = 50,
        },
        types = types, catchRate = 45,
        baseExperience = 64, growthRate = 0,
        gender = { threshold = 127 },
      }
    end
    return DataRegistry.new({
      species = {
        species("fire", { "fire" }),
        species("grass", { "grass" }),
        species("normal", { "normal" }),
      },
      moves = {
        {
          id = "ember", name = "EMBER", type = "fire",
          power = 40, accuracy = 255, pp = 25,
        },
        {
          id = "tackle", name = "TACKLE", type = "normal",
          power = 40, accuracy = 242, pp = 35,
        },
        {
          id = "sleep_powder", name = "SLEEP POWDER",
          type = "grass", power = 0, accuracy = 191, pp = 15,
          effectId = "battle.effect.inflict_sleep",
        },
      },
    })
  end

  local function mon(records, speciesId, moveIds)
    local moves = {}
    for index, id in ipairs(moveIds) do
      moves[index] = {
        id = id,
        pp = records:get("moves", id).pp,
      }
    end
    return PokemonInstance.new(
      records:get("species", speciesId),
      { level = 5, moves = moves }
    )
  end

  local function state(records, opponentParty, rng)
    return BattleState.new({
      kind = "trainer",
      rng = rng or SequenceRng.new({ 0 }),
      playerParty = { mon(records, "grass", { "tackle" }) },
      opponentParty = opponentParty,
    })
  end

  test("smart trainer AI chooses a super-effective move", function()
    local records = registry()
    local battle = state(records, {
      mon(records, "fire", { "tackle", "ember" }),
    })
    local action =
      TrainerAi.new(records):chooseAction(battle, "battle.ai.smart")
    equal(action.kind, "move")
    equal(action.moveIndex, 2)
  end)

  test("smart trainer AI avoids redundant major status", function()
    local records = registry()
    local battle = state(records, {
      mon(records, "grass", { "sleep_powder", "tackle" }),
    })
    battle.player:active().status = { id = "poison" }
    local action =
      TrainerAi.new(records):chooseAction(battle, "battle.ai.smart")
    equal(action.moveIndex, 2)
  end)

  test("smart trainer AI switches a critical active Pokemon", function()
    local records = registry()
    local first = mon(records, "normal", { "tackle" })
    local second = mon(records, "fire", { "ember" })
    first.currentHP = math.floor(first.stats.hp / 5)
    local battle = state(records, { first, second })
    local action =
      TrainerAi.new(records):chooseAction(battle, "battle.ai.smart")
    equal(action.kind, "switch")
    equal(action.partyIndex, 2)
  end)

  test("basic trainer AI uses deterministic legal selection", function()
    local records = registry()
    local battle = state(
      records,
      { mon(records, "fire", { "tackle", "ember" }) },
      SequenceRng.new({ 1 })
    )
    local action =
      TrainerAi.new(records):chooseAction(battle, "battle.ai.basic")
    equal(action.moveIndex, 2)
  end)
end
