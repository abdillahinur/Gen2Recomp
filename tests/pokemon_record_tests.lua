return function(test, equal, truthy, raises)
  local DataRegistry = require("src.pokemon.DataRegistry")

  local function data()
    return {
      species = {
        {
          id = "crystal.species.cyndaquil",
          name = "CYNDAQUIL",
          stats = {
            hp = 39,
            attack = 52,
            defense = 43,
            speed = 65,
            specialAttack = 60,
            specialDefense = 50,
          },
          types = { "fire" },
          catchRate = 45,
          baseExperience = 65,
          growthRate = 3,
          gender = { threshold = 31 },
        },
      },
      moves = {
        {
          id = "crystal.move.tackle",
          name = "TACKLE",
          type = "normal",
          power = 35,
          accuracy = 242,
          pp = 35,
        },
      },
      items = {
        {
          id = "crystal.item.poke_ball",
          name = "POKE BALL",
          kind = "ball",
          price = 200,
        },
      },
      trainers = {
        {
          id = "crystal.trainer.rival_1",
          name = "RIVAL",
          classId = "crystal.trainer_class.rival",
          party = {
            {
              speciesId = "crystal.species.cyndaquil",
              level = 5,
              moves = { "crystal.move.tackle" },
            },
          },
        },
      },
    }
  end

  test("battle data registry normalizes all four record families", function()
    local registry = DataRegistry.new(data())
    equal(
      registry:get("species", "crystal.species.cyndaquil").stats.speed,
      65
    )
    equal(
      registry:get("moves", "crystal.move.tackle").priority,
      0
    )
    equal(
      registry:get("items", "crystal.item.poke_ball")
        .catchRateModifier,
      1
    )
    equal(
      registry:get("trainers", "crystal.trainer.rival_1")
        .aiProfileId,
      "battle.ai.basic"
    )
  end)

  test("battle records reject malformed and duplicate data", function()
    local malformed = data()
    malformed.species[1].stats.hp = 0
    raises(function() DataRegistry.new(malformed) end, "stats.hp")

    local duplicate = data()
    duplicate.moves[2] = duplicate.moves[1]
    raises(function() DataRegistry.new(duplicate) end, "duplicate moves")

    raises(function()
      DataRegistry.new(data()):get("moves", "missing")
    end, "unknown moves")
    truthy(DataRegistry.new().moves)
  end)
end
