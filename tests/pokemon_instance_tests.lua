return function(test, equal, truthy, raises)
  local PokemonInstance =
    require("src.pokemon.PokemonInstance")
  local SpeciesRecord = require("src.pokemon.SpeciesRecord")

  local function cyndaquil()
    return SpeciesRecord.normalize({
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
    })
  end

  test("Gen 2 integer formulas calculate level-five starter stats", function()
    local pokemon = PokemonInstance.new(cyndaquil(), {
      level = 5,
      dvs = {
        hp = 15,
        attack = 15,
        defense = 15,
        speed = 15,
        special = 15,
      },
      moves = {
        { id = "crystal.move.tackle", pp = 35 },
      },
    })
    equal(pokemon.stats.hp, 20)
    equal(pokemon.stats.attack, 11)
    equal(pokemon.stats.defense, 10)
    equal(pokemon.stats.speed, 13)
    equal(pokemon.stats.specialAttack, 12)
    equal(pokemon.stats.specialDefense, 11)
    equal(pokemon.currentHP, 20)
    equal(pokemon.moves[1].maxPP, 35)
    equal(pokemon.gender, "male")
    equal(pokemon.hiddenPower.type, "dark")
  end)

  test("Pokemon instances track damage healing PP and restoration", function()
    local pokemon = PokemonInstance.new(cyndaquil(), {
      level = 5,
      moves = {
        { id = "crystal.move.tackle", pp = 20, maxPP = 35 },
      },
    })
    equal(pokemon:damage(7), 7)
    equal(pokemon:heal(3), 3)
    truthy(not pokemon:isFainted())
    pokemon:damage(999)
    truthy(pokemon:isFainted())
    pokemon.status = "poison"
    pokemon:restore()
    equal(pokemon.currentHP, pokemon.stats.hp)
    equal(pokemon.moves[1].pp, 35)
    equal(pokemon.status, nil)
  end)

  test("Pokemon instances reject invalid levels and move slots", function()
    raises(function()
      PokemonInstance.new(cyndaquil(), { level = 101 })
    end, "level")
    raises(function()
      PokemonInstance.new(cyndaquil(), {
        moves = {
          { id = "a", pp = 1 },
          { id = "b", pp = 1 },
          { id = "c", pp = 1 },
          { id = "d", pp = 1 },
          { id = "e", pp = 1 },
        },
      })
    end, "at most four")
  end)
end
