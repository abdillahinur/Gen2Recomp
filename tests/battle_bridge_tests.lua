return function(test, equal, truthy, raises)
  local BattleBridge = require("src.battle.BattleBridge")
  local BattleRequestFactory =
    require("src.battle.BattleRequestFactory")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local GameSession = require("src.game.GameSession")
  local StateStack = require("src.core.StateStack")

  local function species(id, name)
    return {
      id = id,
      name = name,
      stats = {
        hp = 60, attack = 60, defense = 60, speed = 60,
        specialAttack = 60, specialDefense = 60,
      },
      types = { "normal" },
      catchRate = 100,
      baseExperience = 60,
      growthRate = 0,
      gender = { threshold = 127 },
    }
  end

  local function fixture()
    local speciesIds = {}
    for index = 1, 158 do
      speciesIds[index] = "unused.species_" .. index
    end
    speciesIds[16] = "crystal.species.016.pidgey"
    speciesIds[152] = "crystal.species.152.chikorita"
    speciesIds[155] = "crystal.species.155.cyndaquil"
    speciesIds[158] = "crystal.species.158.totodile"
    local moveIds = {
      [10] = "crystal.move.010.scratch",
      [33] = "crystal.move.033.tackle",
      [43] = "crystal.move.043.leer",
      [45] = "crystal.move.045.growl",
    }
    local data = {
      speciesIds = speciesIds,
      moveIds = moveIds,
    }
    local registry = DataRegistry.new({
      species = {
        species(speciesIds[16], "PIDGEY"),
        species(speciesIds[152], "CHIKORITA"),
        species(speciesIds[155], "CYNDAQUIL"),
        species(speciesIds[158], "TOTODILE"),
      },
      moves = {
        {
          id = moveIds[10], name = "SCRATCH", type = "normal",
          power = 40, accuracy = 255, pp = 35,
        },
        {
          id = moveIds[33], name = "TACKLE", type = "normal",
          power = 35, accuracy = 255, pp = 35,
        },
        {
          id = moveIds[43], name = "LEER", type = "normal",
          power = 0, accuracy = 255, pp = 30,
        },
        {
          id = moveIds[45], name = "GROWL", type = "normal",
          power = 0, accuracy = 255, pp = 40,
        },
      },
    })
    local game = GameSession.new("test_profile")
    game.party:give("crystal.species.cyndaquil", 5)
    return registry, data, game
  end

  local function input(action)
    return {
      wasPressed = function(_, candidate)
        return action == candidate
      end,
    }
  end

  test("battle request factory adapts and commits persistent party state",
    function()
      local registry, data, game = fixture()
      local factory = BattleRequestFactory.new(registry, data, game)
      local session = factory:create({
        kind = "wild",
        opponentId = "crystal.species.pidgey",
        options = { seed = 1 },
      })
      equal(session.state.player:active().species.name, "CYNDAQUIL")
      equal(#session.state.player:active().moves, 2)
      equal(session.state.opponent:active().species.name, "PIDGEY")
      session.state.player:active():damage(1)
      session:run()
      local result = factory:commit(session)
      truthy(result.escaped)
      truthy(game.party.members[1].currentHP)
      equal(#game.party.members[1].moves, 2)
      truthy(game.pokedex.seen["crystal.species.pidgey"])

      local snapshot = game:snapshot()
      snapshot.party[1].moves[1].pp = 0
      truthy(game.party.members[1].moves[1].pp > 0)
    end)

  test("battle bridge pushes visible state and resolves after pop",
    function()
      local registry, data, game = fixture()
      local states = StateStack.new()
      local base = { opaque = true }
      states:push(base)
      local bridge = BattleBridge.new(
        states,
        BattleRequestFactory.new(registry, data, game)
      )
      local result
      local scene = bridge:start({
        kind = "wild",
        opponentId = "crystal.species.pidgey",
        options = { seed = 1 },
      }, function(value) result = value end)
      equal(states:current(), scene)
      scene:update(0, input("confirm"))
      scene:update(0, input("right"))
      scene:update(0, input("down"))
      scene:update(0, input("confirm"))
      while scene.presentation:model().kind == "message" do
        scene:update(0, input("confirm"))
      end
      equal(scene.presentation:model().kind, "complete")
      scene:update(0, input("confirm"))
      equal(states:current(), base)
      truthy(result.escaped)
      equal(bridge.active, nil)
    end)

  test("battle request factory rejects unknown trainers", function()
    local registry, data, game = fixture()
    local factory = BattleRequestFactory.new(registry, data, game)
    raises(function()
      factory:create({
        kind = "trainer",
        opponentId = "crystal.trainer.unknown",
      })
    end, "unknown trainer")
  end)
end
