return function(test, equal, truthy, raises)
  local CrystalBattleData =
    require("src.import.CrystalBattleData")

  test("Crystal battle adapter normalizes species and move bytes", function()
    local species = CrystalBattleData.normalizeSpecies({
      name = "TESTMON",
      stats = {
        hp = 45, attack = 49, defense = 49, speed = 45,
        specialAttack = 65, specialDefense = 65,
      },
      types = { 22, 22 },
      catchRate = 45,
      baseExperience = 64,
      growthRate = 3,
      gender = { threshold = 31 },
    }, 152)
    equal(species.id, "crystal.species.152.testmon")
    equal(species.types[1], "grass")
    equal(#species.types, 1)

    local move = CrystalBattleData.decodeMove(
      string.char(33, 0, 35, 0, 242, 35, 0),
      33,
      "TACKLE"
    )
    equal(move.id, "crystal.move.033.tackle")
    equal(move.type, "normal")
    equal(move.power, 35)
    equal(move.effectId, "battle.effect.none")

    local quick = CrystalBattleData.decodeMove(
      string.char(98, 103, 40, 0, 255, 30, 0),
      98,
      "QUICK ATTACK"
    )
    equal(quick.priority, 1)
  end)

  test("Crystal battle adapter rejects corrupt move records", function()
    raises(function()
      CrystalBattleData.decodeMove(
        string.char(32, 0, 35, 0, 242, 35, 0),
        33,
        "TACKLE"
      )
    end, "stores id")
    raises(function()
      CrystalBattleData.decodeMove("short", 1, "MOVE")
    end, "seven bytes")
  end)
end
