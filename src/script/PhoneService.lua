local PhoneService = {}
PhoneService.__index = PhoneService

function PhoneService.new()
  return setmetatable({ contacts = {}, order = {} }, PhoneService)
end

function PhoneService:register(contactId)
  if type(contactId) ~= "string" or contactId == "" then
    error("phone service: contact id is required", 2)
  end
  if not self.contacts[contactId] then
    self.contacts[contactId] = true
    self.order[#self.order + 1] = contactId
  end
  return true
end

function PhoneService:has(contactId)
  return self.contacts[contactId] == true
end

return PhoneService
