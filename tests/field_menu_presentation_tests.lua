return function(test, equal, truthy)
  local FieldMenuPresentation =
    require("src.ui.FieldMenuPresentation")
  local GameSession = require("src.game.GameSession")

  local function input(action)
    return {
      wasPressed = function(_, candidate)
        return action == candidate
      end,
    }
  end

  local function species(id, name, hp)
    return {
      id = id,
      name = name,
      stats = {
        hp = hp,
        attack = 49,
        defense = 49,
        speed = 45,
        specialAttack = 65,
        specialDefense = 65,
      },
    }
  end

  local function fixture()
    local game = GameSession.new("crystal_us_11")
    local data = {
      species = {
        species("crystal.species.001.bulbasaur", "BULBASAUR", 45),
        species("crystal.species.016.pidgey", "PIDGEY", 40),
        species("crystal.species.019.rattata", "RATTATA", 30),
      },
    }
    return game, data
  end

  test("field menu gates the Pokedex and closes from its root",
    function()
      local game, data = fixture()
      local closed = 0
      local menu = FieldMenuPresentation.new(game, data, {
        onClose = function() closed = closed + 1 end,
      })
      truthy(menu:model().options[1].disabled)
      menu:update(input("confirm"))
      equal(menu:model().kind, "root")

      game.state:setFlag("crystal.feature.pokedex")
      menu:update(input("confirm"))
      equal(menu:model().kind, "pokedex")
      menu:update(input("start"))
      equal(closed, 1)
    end)

  test("field menu presents persistent Pack quantities", function()
    local game, data = fixture()
    game.inventory:give("crystal.item.potion", 2)
    game.inventory:give("crystal.item.berry", 1)
    local menu = FieldMenuPresentation.new(game, data)
    menu:update(input("down"))
    menu:update(input("down"))
    menu:update(input("confirm"))
    local pack = menu:model()
    equal(pack.kind, "pack")
    equal(pack.options[1].name, "BERRY")
    equal(pack.options[1].quantity, 1)
    equal(pack.options[2].name, "POTION")
    equal(pack.options[2].quantity, 2)
    menu:update(input("cancel"))
    equal(menu:model().selected, 3)
  end)

  test("field menu calculates party summaries from ROM species",
    function()
      local game, data = fixture()
      game.party:give(
        "crystal.species.bulbasaur",
        5,
        "crystal.item.berry",
        {
          nickname = "BUD",
          currentHP = 18,
          dvs = {
            attack = 10,
            defense = 10,
            speed = 10,
            special = 10,
          },
        }
      )
      local menu = FieldMenuPresentation.new(game, data)
      menu:update(input("down"))
      menu:update(input("confirm"))
      local party = menu:model()
      equal(party.kind, "party")
      equal(party.options[1].name, "BUD")
      equal(party.options[1].level, 5)
      equal(party.options[1].hp, 18)
      equal(party.options[1].maxHP, 19)
      equal(party.options[1].heldItem, "BERRY")
      menu:update(input("cancel"))
      equal(menu:model().selected, 2)
    end)

  test("field menu hides unseen Pokedex names and counts catches",
    function()
      local game, data = fixture()
      game.state:setFlag("crystal.feature.pokedex")
      game:markCaught("crystal.species.bulbasaur")
      game:markSeen("crystal.species.pidgey")
      local menu = FieldMenuPresentation.new(game, data)
      menu:update(input("confirm"))
      local pokedex = menu:model()
      equal(pokedex.kind, "pokedex")
      equal(pokedex.seen, 2)
      equal(pokedex.caught, 1)
      equal(pokedex.options[1].name, "BULBASAUR")
      truthy(pokedex.options[1].caught)
      equal(pokedex.options[2].name, "PIDGEY")
      equal(pokedex.options[3].name, "----------")
      menu:update(input("down"))
      equal(menu:model().selected, 2)
    end)
end
