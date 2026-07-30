local Collision = {}
Collision.__index = Collision

local function contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then
      return true
    end
  end
  return false
end

function Collision.new(permissionRecords)
  local permissions = {}
  for _, record in ipairs(permissionRecords or {}) do
    permissions[record.id] = record
  end
  return setmetatable({ permissions = permissions }, Collision)
end

function Collision:permission(collisionId)
  return self.permissions[collisionId]
end

function Collision:allows(collisionId, direction)
  local permission = self:permission(collisionId)
  if not permission or permission.terrain ~= "land" then
    return false
  end
  if not permission.directional then
    return true
  end
  if permission.directionKind == "ledge" then
    return contains(permission.directions, direction)
  end
  return not contains(permission.directions, direction)
end

return Collision
