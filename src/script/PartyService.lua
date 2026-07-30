local PartyService = {}
PartyService.__index = PartyService

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end

function PartyService.new(options)
  options = options or {}
  local capacity = options.capacity or 6
  if type(capacity) ~= "number"
      or capacity % 1 ~= 0
      or capacity < 1 then
    error("party service: capacity must be a positive integer", 2)
  end
  return setmetatable({
    capacity = capacity,
    members = {},
  }, PartyService)
end

function PartyService:give(speciesId, level, heldItemId, options)
  options = options or {}
  if type(speciesId) ~= "string" or speciesId == "" then
    error("party service: species id is required", 2)
  end
  if type(level) ~= "number" or level % 1 ~= 0
      or level < 1 or level > 100 then
    error("party service: level must be an integer from 1 to 100", 2)
  end
  if #self.members >= self.capacity then
    return nil, "party_full"
  end
  local member = {
    speciesId = speciesId,
    level = level,
    heldItemId = heldItemId,
    nickname = options.nickname,
    currentHP = options.currentHP,
    experience = options.experience,
    dvs = copy(options.dvs),
    moves = copy(options.moves),
  }
  self.members[#self.members + 1] = member
  return member
end

function PartyService:remove(index, allowEmpty)
  if type(index) ~= "number" or index % 1 ~= 0
      or index < 1 or index > #self.members then
    return nil, "invalid_party_index"
  end
  if #self.members == 1 and not allowEmpty then
    return nil, "last_party_member"
  end
  return table.remove(self.members, index)
end

function PartyService:store(member)
  if type(member) ~= "table" or type(member.speciesId) ~= "string" then
    error("party service: stored member is invalid", 2)
  end
  if #self.members >= self.capacity then return nil, "party_full" end
  self.members[#self.members + 1] = copy(member)
  return self.members[#self.members]
end

return PartyService
