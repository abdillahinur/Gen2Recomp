local ProgressionCommandHandlers = {}

function ProgressionCommandHandlers.install(runner, services)
  local party = assert(services.party, "party service is required")
  local inventory =
    assert(services.inventory, "inventory service is required")
  local phone = assert(services.phone, "phone service is required")

  runner:register("party.pokemon.give", function(arguments)
    local member, reason = party:give(
      arguments.speciesId,
      arguments.level,
      arguments.heldItemId
    )
    if not member then error("could not give Pokemon: " .. reason) end
    return member
  end)
  runner:register("inventory.item.give", function(arguments)
    return inventory:give(arguments.itemId, arguments.count)
  end)
  runner:register("phone.contact.register", function(arguments)
    return phone:register(arguments.id)
  end)
end

return ProgressionCommandHandlers
