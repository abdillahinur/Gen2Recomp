return function(test, equal, truthy, raises)
  local BattleEngine = require("src.battle.BattleEngine")
  local BattleState = require("src.battle.BattleState")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")

  local function registry()
    return DataRegistry.new({
      species = {
        {
          id = "fast", name = "FAST",
          stats = {
            hp = 40, attack = 40, defense = 40, speed = 80,
            specialAttack = 40, specialDefense = 40,
          },
          types = { "normal" }, catchRate = 45,
          baseExperience = 64, growthRate = 0,
          gender = { threshold = 127 },
        },
        {
          id = "slow", name = "SLOW",
          stats = {
            hp = 40, attack = 40, defense = 40, speed = 20,
            specialAttack = 40, specialDefense = 40,
          },
          types = { "normal" }, catchRate = 45,
          baseExperience = 64, growthRate = 0,
          gender = { threshold = 127 },
        },
      },
      moves = {
        {
          id = "quick", name = "QUICK", type = "normal",
          power = 40, accuracy = 255, pp = 30, priority = 1,
        },
        {
          id = "tackle", name = "TACKLE", type = "normal",
          power = 35, accuracy = 242, pp = 35,
        },
      },
    })
  end

  local function mon(records, speciesId, moveId)
    local move = records:get("moves", moveId)
    return PokemonInstance.new(
      records:get("species", speciesId),
      {
        level = 5,
        moves = { { id = moveId, pp = move.pp } },
      }
    )
  end

  test("move priority orders actions before Speed", function()
    local records = registry()
    local state = BattleState.new({
      kind = "trainer",
      playerParty = { mon(records, "fast", "tackle") },
      opponentParty = { mon(records, "slow", "quick") },
    })
    local engine = BattleEngine.new(state, records)
    engine:submit("player", { kind = "move", moveIndex = 1 })
    local order =
      engine:submit("opponent", { kind = "move", moveIndex = 1 })
    equal(order[1].sideId, "opponent")
    equal(state.turn, 2)
    equal(state.player:active().moves[1].pp, 34)
  end)

  test("switches resolve before moves and change the target", function()
    local records = registry()
    local hitTarget
    local state = BattleState.new({
      kind = "trainer",
      playerParty = {
        mon(records, "fast", "tackle"),
        mon(records, "slow", "tackle"),
      },
      opponentParty = { mon(records, "slow", "tackle") },
    })
    local engine = BattleEngine.new(state, records, {
      moveExecutor = function(_, _, _, target)
        hitTarget = target
      end,
    })
    engine:submit("player", { kind = "switch", partyIndex = 2 })
    local order =
      engine:submit("opponent", { kind = "move", moveIndex = 1 })
    equal(order[1].kind, "switch")
    equal(state.player.activeIndex, 2)
    equal(hitTarget, state.player.party[2])
  end)

  test("Speed ties consume injected randomness and actions validate", function()
    local records = registry()
    local state = BattleState.new({
      kind = "wild",
      rng = SequenceRng.new({ 0 }),
      playerParty = { mon(records, "fast", "tackle") },
      opponentParty = { mon(records, "fast", "tackle") },
    })
    local engine = BattleEngine.new(state, records)
    engine:submit("player", { kind = "move", moveIndex = 1 })
    local order =
      engine:submit("opponent", { kind = "move", moveIndex = 1 })
    equal(order[1].sideId, "player")
    equal(state.rng.draws, 1)

    raises(function()
      engine:submit("player", { kind = "switch", partyIndex = 1 })
    end, "already active")
    truthy(state.phase == "command")
  end)
end
