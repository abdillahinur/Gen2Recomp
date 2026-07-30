return function(test, equal, truthy)
  local BattleSession = require("src.battle.BattleSession")
  local BattleState = require("src.battle.BattleState")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")

  local function records()
    return DataRegistry.new({
      species = {
        {
          id = "hero", name = "HERO",
          stats = {
            hp = 100, attack = 255, defense = 100, speed = 255,
            specialAttack = 100, specialDefense = 100,
          },
          types = { "normal" }, catchRate = 45,
          baseExperience = 100, growthRate = 0,
          gender = { threshold = 127 },
        },
        {
          id = "foe", name = "FOE",
          stats = {
            hp = 10, attack = 10, defense = 10, speed = 10,
            specialAttack = 10, specialDefense = 10,
          },
          types = { "normal" }, catchRate = 255,
          baseExperience = 20, growthRate = 0,
          gender = { threshold = 127 },
        },
      },
      moves = {
        {
          id = "finish", name = "FINISH", type = "normal",
          power = 255, accuracy = 255, pp = 10,
        },
        {
          id = "tap", name = "TAP", type = "normal",
          power = 1, accuracy = 255, pp = 10,
        },
      },
    })
  end

  local function mon(registry, speciesId, level, moveId)
    local move = registry:get("moves", moveId)
    return PokemonInstance.new(
      registry:get("species", speciesId),
      {
        level = level,
        moves = { { id = moveId, pp = move.pp } },
      }
    )
  end

  test("battle session forces replacements and reaches player win", function()
    local registry = records()
    local state = BattleState.new({
      kind = "trainer",
      rng = SequenceRng.new({ 255 }),
      playerParty = { mon(registry, "hero", 100, "finish") },
      opponentParty = {
        mon(registry, "foe", 2, "tap"),
        mon(registry, "foe", 2, "tap"),
      },
    })
    local session = BattleSession.new(registry, { state = state })
    equal(session:runToCompletion(4), "player_win")
    equal(state.phase, "complete")
    equal(state.opponent.activeIndex, 2)

    local forced = 0
    local experience = 0
    for _, event in ipairs(state.events) do
      if event.kind == "battle.forced_switch" then forced = forced + 1 end
      if event.kind == "battle.experience_gained" then
        experience = experience + 1
      end
    end
    equal(forced, 1)
    equal(experience, 2)
  end)

  test("battle session reports an opponent victory", function()
    local registry = records()
    local state = BattleState.new({
      kind = "wild",
      rng = SequenceRng.new({ 255 }),
      playerParty = { mon(registry, "foe", 2, "tap") },
      opponentParty = { mon(registry, "hero", 100, "finish") },
    })
    local session = BattleSession.new(registry, { state = state })
    equal(session:runToCompletion(4), "opponent_win")
    truthy(state.player:active():isFainted())
  end)
end
