return function(test, equal, truthy)
  local BattlePresentation =
    require("src.ui.BattlePresentation")
  local BattleSession = require("src.battle.BattleSession")
  local BattleState = require("src.battle.BattleState")
  local DataRegistry = require("src.pokemon.DataRegistry")
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SequenceRng = require("src.battle.SequenceRng")

  local function input(action)
    return {
      wasPressed = function(_, candidate)
        return action == candidate
      end,
    }
  end

  local function registry()
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
          id = "friend", name = "FRIEND",
          stats = {
            hp = 80, attack = 80, defense = 80, speed = 80,
            specialAttack = 80, specialDefense = 80,
          },
          types = { "normal" }, catchRate = 45,
          baseExperience = 80, growthRate = 0,
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
      items = {
        {
          id = "master_ball",
          name = "MASTER BALL",
          kind = "ball",
          price = 0,
          master = true,
        },
      },
    })
  end

  local function mon(records, speciesId, moveId)
    local move = records:get("moves", moveId)
    return PokemonInstance.new(
      records:get("species", speciesId),
      {
        level = speciesId == "hero" and 100 or 2,
        moves = { { id = moveId, pp = move.pp } },
      }
    )
  end

  local function session(kind, second)
    local records = registry()
    local party = { mon(records, "hero", "finish") }
    if second then
      party[2] = mon(records, "friend", "tap")
    end
    return BattleSession.new(records, {
      state = BattleState.new({
        kind = kind or "wild",
        rng = SequenceRng.new({ 255 }),
        playerParty = party,
        opponentParty = { mon(records, "foe", "tap") },
      }),
    })
  end

  local function closeMessages(presentation)
    local guard = 0
    while presentation:model().kind == "message" do
      guard = guard + 1
      if guard > 30 then error("battle messages did not finish") end
      presentation:update(input("confirm"))
    end
  end

  test("battle presentation drives Fight to a visible outcome", function()
    local value = session("wild")
    local completed
    local presentation = BattlePresentation.new(value, {
      onComplete = function(outcome) completed = outcome end,
    })
    equal(presentation:model().kind, "message")
    presentation:update(input("confirm"))
    equal(presentation:model().kind, "root")
    presentation:update(input("confirm"))
    local moves = presentation:model()
    equal(moves.kind, "moves")
    equal(moves.options[1].name, "FINISH")
    equal(moves.options[1].pp, 10)
    presentation:update(input("confirm"))
    closeMessages(presentation)
    equal(presentation:model().kind, "complete")
    equal(presentation:model().outcome, "player_win")
    presentation:update(input("confirm"))
    equal(completed, "player_win")
  end)

  test("battle presentation exposes party switching", function()
    local value = session("trainer", true)
    local presentation = BattlePresentation.new(value)
    presentation:update(input("confirm"))
    presentation:update(input("down"))
    presentation:update(input("confirm"))
    local party = presentation:model()
    equal(party.kind, "party")
    truthy(party.options[1].active)
    presentation:update(input("down"))
    presentation:update(input("confirm"))
    equal(value.state.player.activeIndex, 2)
    closeMessages(presentation)
    equal(presentation:model().kind, "root")
  end)

  test("battle presentation catches from Pack and runs from wilds",
    function()
      local caught = session("wild")
      local pack = BattlePresentation.new(caught, {
        items = { { id = "master_ball", quantity = 1 } },
      })
      pack:update(input("confirm"))
      pack:update(input("right"))
      pack:update(input("confirm"))
      equal(pack:model().kind, "pack")
      pack:update(input("confirm"))
      closeMessages(pack)
      equal(pack:model().outcome, "caught")

      local escaped = session("wild")
      local run = BattlePresentation.new(escaped)
      run:update(input("confirm"))
      run:update(input("right"))
      run:update(input("down"))
      run:update(input("confirm"))
      closeMessages(run)
      equal(run:model().outcome, "escaped")
    end)

  test("trainer battle Run command fails visibly", function()
    local value = session("trainer")
    local presentation = BattlePresentation.new(value)
    presentation:update(input("confirm"))
    presentation:update(input("right"))
    presentation:update(input("down"))
    presentation:update(input("confirm"))
    equal(presentation:model().kind, "message")
    closeMessages(presentation)
    equal(presentation:model().kind, "root")
    equal(value.state.phase, "command")
  end)
end
