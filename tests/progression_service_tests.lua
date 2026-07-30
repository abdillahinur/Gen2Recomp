return function(test, equal, truthy, raises)
  local InventoryService =
    require("src.script.InventoryService")
  local PartyService = require("src.script.PartyService")
  local PhoneService = require("src.script.PhoneService")

  test("progression services retain party inventory and phone state", function()
    local party = PartyService.new()
    local inventory = InventoryService.new()
    local phone = PhoneService.new()

    local starter = party:give(
      "crystal.species.cyndaquil",
      5,
      "crystal.item.berry"
    )
    equal(#party.members, 1)
    equal(starter.speciesId, "crystal.species.cyndaquil")
    equal(starter.level, 5)
    equal(starter.heldItemId, "crystal.item.berry")

    equal(inventory:give("crystal.item.potion", 1), 1)
    equal(inventory:give("crystal.item.potion", 2), 3)
    equal(inventory:count("crystal.item.potion"), 3)

    truthy(phone:register("crystal.phone.professor_elm"))
    truthy(phone:register("crystal.phone.professor_elm"))
    truthy(phone:has("crystal.phone.professor_elm"))
    equal(#phone.order, 1)
  end)

  test("progression services reject invalid grants and full parties", function()
    raises(function()
      PartyService.new():give("", 5)
    end, "species id")
    raises(function()
      PartyService.new():give("crystal.species.cyndaquil", 0)
    end, "level")
    raises(function()
      InventoryService.new():give("crystal.item.potion", 0)
    end, "positive integer")
    raises(function()
      PhoneService.new():register("")
    end, "contact id")

    local party = PartyService.new({ capacity = 1 })
    truthy(party:give("crystal.species.cyndaquil", 5))
    local member, reason =
      party:give("crystal.species.totodile", 5)
    equal(member, nil)
    equal(reason, "party_full")
  end)
end
