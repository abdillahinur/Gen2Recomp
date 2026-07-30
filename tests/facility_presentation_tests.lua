return function(test, equal)
  local FacilityPresentation =
    require("src.ui.FacilityPresentation")
  local FacilityService = require("src.game.FacilityService")
  local GameSession = require("src.game.GameSession")

  local function input(action)
    return {
      wasPressed = function(_, candidate)
        return action == candidate
      end,
    }
  end

  local function service()
    local game = GameSession.new("crystal_us_11", { money = 1000 })
    game.party:give(
      "crystal.species.cyndaquil", 5, nil,
      { currentHP = 1 })
    return game, FacilityService.new(game, {
      species = {
        {
          id = "crystal.species.155.cyndaquil",
          name = "CYNDAQUIL",
          stats = {
            hp = 39, attack = 52, defense = 43, speed = 65,
            specialAttack = 60, specialDefense = 50,
          },
        },
      },
    })
  end

  test("center presentation heals and exposes PC storage", function()
    local game, value = service()
    local center = FacilityPresentation.new("center", value)
    center:update(input("confirm"))
    equal(center:model().kind, "message")
    equal(game.party.members[1].currentHP, 18)
    center:update(input("confirm"))
    center:update(input("down"))
    center:update(input("confirm"))
    equal(center:model().title, "BILL'S PC")
    center:update(input("confirm"))
    equal(center:model().title, "DEPOSIT")
  end)

  test("mart presentation completes a visible purchase", function()
    local game, value = service()
    local mart = FacilityPresentation.new(
      "mart", value, { catalogId = "cherrygrove" })
    mart:update(input("confirm"))
    equal(mart:model().title, "BUY")
    mart:update(input("confirm"))
    equal(mart:model().kind, "message")
    equal(game.inventory:count("crystal.item.potion"), 1)
    equal(game.money, 700)
  end)
end
