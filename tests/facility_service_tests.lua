return function(test, equal, truthy)
  local FacilityService = require("src.game.FacilityService")
  local GameSession = require("src.game.GameSession")

  local function fixture()
    local game = GameSession.new("crystal_us_11", { money = 2000 })
    local data = {
      species = {
        {
          id = "crystal.species.155.cyndaquil",
          name = "CYNDAQUIL",
          stats = {
            hp = 39, attack = 52, defense = 43, speed = 65,
            specialAttack = 60, specialDefense = 50,
          },
        },
        {
          id = "crystal.species.016.pidgey",
          name = "PIDGEY",
          stats = {
            hp = 40, attack = 45, defense = 40, speed = 56,
            specialAttack = 35, specialDefense = 35,
          },
        },
      },
    }
    game.party:give(
      "crystal.species.cyndaquil", 5, nil,
      { currentHP = 1 })
    game.party:give(
      "crystal.species.pidgey", 3, nil,
      { currentHP = 2 })
    return game, FacilityService.new(game, data)
  end

  test("facility service heals and consumes a field Potion",
    function()
      local game, service = fixture()
      equal(service:healParty(), 2)
      equal(game.party.members[1].currentHP, 18)
      game.party.members[1].currentHP = 1
      game.inventory:give("crystal.item.potion", 1)
      equal(service:usePotion(1), 17)
      equal(game.party.members[1].currentHP, 18)
      equal(game.inventory:count("crystal.item.potion"), 0)
    end)

  test("facility service buys and sells against session money",
    function()
      local game, service = fixture()
      equal(#service:catalog("violet"), 9)
      equal(service:buy("crystal.item.potion", 2), 600)
      equal(game.money, 1400)
      equal(game.inventory:count("crystal.item.potion"), 2)
      equal(service:sell("crystal.item.potion", 1), 150)
      equal(game.money, 1550)
      equal(game.inventory:count("crystal.item.potion"), 1)
      local value, reason =
        service:buy("crystal.item.escape_rope", 99)
      equal(value, nil)
      equal(reason, "not_enough_money")
    end)

  test("PC storage preserves Pokemon and party constraints",
    function()
      local game = fixture()
      local deposited = game.storage:depositPokemon(game.party, 2)
      equal(deposited.speciesId, "crystal.species.pidgey")
      equal(#game.party.members, 1)
      equal(#game.storage.pokemon, 1)
      local value, reason =
        game.storage:depositPokemon(game.party, 1)
      equal(value, nil)
      equal(reason, "last_party_member")
      truthy(game.storage:withdrawPokemon(game.party, 1))
      equal(#game.party.members, 2)
      equal(#game.storage.pokemon, 0)
    end)
end
