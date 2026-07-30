local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new()
  return setmetatable({ items = {} }, InventoryService)
end

function InventoryService:give(itemId, count)
  if type(itemId) ~= "string" or itemId == "" then
    error("inventory service: item id is required", 2)
  end
  count = count or 1
  if type(count) ~= "number" or count % 1 ~= 0 or count < 1 then
    error("inventory service: count must be a positive integer", 2)
  end
  self.items[itemId] = (self.items[itemId] or 0) + count
  return self.items[itemId]
end

function InventoryService:count(itemId)
  return self.items[itemId] or 0
end

return InventoryService
