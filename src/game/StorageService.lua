local StorageService = {}
StorageService.__index = StorageService

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end

function StorageService.new(snapshot)
  local pokemon = {}
  for index, member in ipairs(snapshot and snapshot.pokemon or {}) do
    pokemon[index] = copy(member)
  end
  local items = {}
  for id, count in pairs(snapshot and snapshot.items or {}) do
    items[id] = count
  end
  return setmetatable({ pokemon = pokemon, items = items }, StorageService)
end

function StorageService:depositPokemon(party, index)
  local member, reason = party:remove(index)
  if not member then return nil, reason end
  self.pokemon[#self.pokemon + 1] = member
  return member
end

function StorageService:withdrawPokemon(party, index)
  local member = self.pokemon[index]
  if not member then return nil, "invalid_storage_index" end
  local stored, reason = party:store(member)
  if not stored then return nil, reason end
  table.remove(self.pokemon, index)
  return stored
end

function StorageService:depositItem(inventory, itemId, count)
  local _, reason = inventory:remove(itemId, count)
  if reason then return nil, reason end
  self.items[itemId] = (self.items[itemId] or 0) + count
  return self.items[itemId]
end

function StorageService:withdrawItem(inventory, itemId, count)
  count = count or 1
  local available = self.items[itemId] or 0
  if available < count then return nil, "not_enough_items" end
  self.items[itemId] = available - count
  if self.items[itemId] == 0 then self.items[itemId] = nil end
  inventory:give(itemId, count)
  return inventory:count(itemId)
end

function StorageService:snapshot()
  return {
    pokemon = copy(self.pokemon),
    items = copy(self.items),
  }
end

return StorageService
