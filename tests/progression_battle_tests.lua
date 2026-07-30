return function(test, equal, truthy)
  local BattleState = require("src.battle.BattleState")
  local CatchSystem = require("src.battle.CatchSystem")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local ExperienceSystem =
    require("src.battle.ExperienceSystem")
  local GrowthRates = require("src.pokemon.GrowthRates")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")

  local function registry()
    return DataRegistry.new({
      species = {
        {
          id = "starter", name = "STARTER",
          stats = {
            hp = 45, attack = 49, defense = 49, speed = 45,
            specialAttack = 65, specialDefense = 65,
          },
          types = { "grass" }, catchRate = 45,
          baseExperience = 64, growthRate = 3,
          gender = { threshold = 31 },
        },
        {
          id = "wild", name = "WILD",
          stats = {
            hp = 40, attack = 40, defense = 40, speed = 40,
            specialAttack = 40, specialDefense = 40,
          },
          types = { "normal" }, catchRate = 255,
          baseExperience = 60, growthRate = 0,
          gender = { threshold = 127 },
        },
      },
      moves = {
        {
          id = "tackle", name = "TACKLE", type = "normal",
          power = 35, accuracy = 242, pp = 35,
        },
        {
          id = "growl", name = "GROWL", type = "normal",
          power = 0, accuracy = 255, pp = 40,
          effectId = "battle.effect.lower_attack",
        },
      },
      items = {
        {
          id = "poke_ball", name = "POKE BALL",
          kind = "ball", price = 200,
        },
      },
    })
  end

  local function mon(records, id, level, moves)
    local slots = {}
    for index, moveId in ipairs(moves or {}) do
      slots[index] = {
        id = moveId,
        pp = records:get("moves", moveId).pp,
      }
    end
    return PokemonInstance.new(
      records:get("species", id),
      { level = level, moves = slots }
    )
  end

  test("all six Crystal growth curves produce level thresholds", function()
    equal(GrowthRates.atLevel(0, 5), 125)
    equal(GrowthRates.atLevel(3, 5), 135)
    equal(GrowthRates.atLevel(4, 5), 100)
    equal(GrowthRates.atLevel(5, 5), 156)
    equal(GrowthRates.levelForExperience(0, 999), 9)
  end)

  test("experience levels up and resolves four-slot move learning",
    function()
      local records = registry()
      local pokemon = mon(records, "starter", 5, {
        "tackle", "tackle", "tackle", "tackle",
      })
      local targetExperience = GrowthRates.atLevel(3, 6)
      local result = ExperienceSystem.gain(
        pokemon,
        targetExperience - pokemon.experience,
        { { level = 6, moveId = "growl" } },
        records,
        function() return 2 end
      )
      equal(result.oldLevel, 5)
      equal(result.newLevel, 6)
      equal(result.learned[1].result, "replaced")
      equal(pokemon.moves[2].id, "growl")
      truthy(pokemon.currentHP > 0)
    end)

  test("experience rewards account for trainer and participants", function()
    local records = registry()
    local defeated = mon(records, "wild", 10)
    equal(ExperienceSystem.reward(defeated), 85)
    equal(ExperienceSystem.reward(defeated, {
      trainer = true,
      participants = 2,
    }), 63)
  end)

  test("catching uses HP status ball rate and injected byte", function()
    local records = registry()
    local player = mon(records, "starter", 5, { "tackle" })
    local target = mon(records, "wild", 3, { "tackle" })
    target.currentHP = 1
    target.status = { id = "sleep", turns = 2 }
    local state = BattleState.new({
      kind = "wild",
      rng = SequenceRng.new({ 0 }),
      playerParty = { player },
      opponentParty = { target },
    })
    local result = CatchSystem.attempt(
      state,
      target,
      records:get("items", "poke_ball")
    )
    truthy(result.caught)
    equal(state.outcome, "caught")

    state = BattleState.new({
      kind = "trainer",
      rng = SequenceRng.new({ 0 }),
      playerParty = { player },
      opponentParty = { target },
    })
    result = CatchSystem.attempt(
      state,
      target,
      records:get("items", "poke_ball")
    )
    truthy(not result.caught)
    equal(result.reason, "trainer_battle")
  end)
end
