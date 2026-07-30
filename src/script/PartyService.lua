local PartyService = {}
PartyService.__index = PartyService

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

function PartyService:give(speciesId, level, heldItemId)
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
  }
  self.members[#self.members + 1] = member
  return member
end

return PartyService
