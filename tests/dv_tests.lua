return function(test, equal, truthy, raises)
  local Dvs = require("src.pokemon.Dvs")

  test("HP DV is derived from the low bit of stored DVs", function()
    local values = Dvs.normalize({
      attack = 15,
      defense = 14,
      speed = 13,
      special = 12,
    })
    equal(values.hp, 10)
  end)

  test("Gen 2 gender compares combined Attack and Speed DVs", function()
    equal(Dvs.gender(0, Dvs.normalize()), "male")
    equal(Dvs.gender(254, Dvs.normalize()), "female")
    equal(Dvs.gender(255, Dvs.normalize()), "genderless")
    equal(Dvs.gender(31, Dvs.normalize({
      attack = 1,
      speed = 15,
    })), "female")
    equal(Dvs.gender(31, Dvs.normalize({
      attack = 2,
      speed = 0,
    })), "male")
  end)

  test("Gen 2 shiny and Hidden Power values use cartridge DVs", function()
    local shiny = Dvs.normalize({
      attack = 2,
      defense = 10,
      speed = 10,
      special = 10,
    })
    truthy(Dvs.isShiny(shiny))
    equal(Dvs.hiddenPower(shiny).type, "grass")
    equal(Dvs.hiddenPower(shiny).power, 49)

    local maximum = Dvs.normalize({
      attack = 15,
      defense = 15,
      speed = 15,
      special = 15,
    })
    truthy(not Dvs.isShiny(maximum))
    equal(Dvs.hiddenPower(maximum).type, "dark")
    equal(Dvs.hiddenPower(maximum).power, 70)
  end)

  test("DVs reject values outside their four-bit range", function()
    raises(function()
      Dvs.normalize({ attack = 16 })
    end, "attack")
  end)
end
