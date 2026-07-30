local Commands = require("src.script.Commands")

local MapHelpers = {}

function MapHelpers.text(id)
  return function() Commands.text(id) end
end

function MapHelpers.item(actorId, flagId, itemId, count)
  return function()
    if Commands.hasFlag(flagId) then return end
    Commands.giveItem(itemId, count or 1)
    Commands.setFlag(flagId)
    if actorId then Commands.hideObject(actorId) end
    Commands.text("crystal.text.common.item_received", {
      item = itemId,
    })
  end
end

function MapHelpers.fruit(flagId, itemId)
  return function()
    if Commands.hasFlag(flagId) then
      Commands.text("crystal.text.common.fruit_tree_empty")
      return
    end
    local fruit = itemId or "crystal.item.berry"
    Commands.giveItem(fruit, 1)
    Commands.setFlag(flagId)
    Commands.text("crystal.text.common.fruit_tree_picked", {
      item = fruit,
    })
  end
end

function MapHelpers.trainer(trainerId, defeatFlagId, afterTextId)
  local flag = "crystal.trainer.defeated.f" .. defeatFlagId
  return function()
    if Commands.hasFlag(flag) then
      Commands.text(afterTextId)
      return
    end
    local result = Commands.battle("trainer", trainerId)
    if result.won then
      Commands.setFlag(flag)
      Commands.text(afterTextId)
    end
  end
end

return MapHelpers
