return function(test, equal, truthy, raises)
  local BattleRng = require("src.battle.BattleRng")
  local BattleState = require("src.battle.BattleState")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")
  local SpeciesRecord = require("src.pokemon.SpeciesRecord")

  local function pokemon(id)
    local species = SpeciesRecord.normalize({
      id = id,
      name = "TEST",
      stats = {
        hp = 40,
        attack = 40,
        defense = 40,
        speed = 40,
        specialAttack = 40,
        specialDefense = 40,
      },
      types = { "normal" },
      catchRate = 45,
      baseExperience = 64,
      growthRate = 0,
      gender = { threshold = 127 },
    })
    return PokemonInstance.new(species, { level = 5 })
  end

  test("seeded battle RNG produces reproducible bytes", function()
    local first = BattleRng.new(1234)
    local second = BattleRng.new(1234)
    for _ = 1, 20 do
      equal(first:nextByte(), second:nextByte())
    end
    equal(first.draws, 20)
    local injected = SequenceRng.new({ 0, 255 })
    equal(injected:range(10, 20), 10)
    equal(injected:range(10, 20), 12)
  end)

  test("battle state owns sides events and detached snapshots", function()
    local state = BattleState.new({
      kind = "wild",
      rng = SequenceRng.new({ 7 }),
      playerParty = { pokemon("crystal.species.cyndaquil") },
      opponentParty = { pokemon("crystal.species.pidgey") },
    })
    state:emit("battle.started")
    local snapshot = state:snapshot()
    equal(snapshot.turn, 1)
    equal(snapshot.phase, "command")
    equal(snapshot.player.activeIndex, 1)
    equal(snapshot.eventCount, 1)
    snapshot.player.party[1].currentHP = 0
    truthy(not state.player:active():isFainted())
  end)

  test("battle state rejects unusable parties and invalid RNGs", function()
    local fainted = pokemon("crystal.species.pidgey")
    fainted:damage(999)
    raises(function()
      BattleState.new({
        kind = "wild",
        playerParty = { pokemon("crystal.species.cyndaquil") },
        opponentParty = { fainted },
      })
    end, "no usable")
    raises(function()
      BattleState.new({
        kind = "link",
        playerParty = { pokemon("a") },
        opponentParty = { pokemon("b") },
      })
    end, "wild or trainer")
  end)
end
