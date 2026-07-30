local MapRepository = {}
MapRepository.__index = MapRepository

function MapRepository.new(worldData)
  local self = setmetatable({
    data = worldData,
    maps = {},
    tilesets = {},
    sprites = {},
    roofs = {},
  }, MapRepository)

  for _, group in ipairs(worldData.groups or {}) do
    for _, map in ipairs(group.maps or {}) do
      self.maps[map.id] = map
    end
  end
  for _, tileset in ipairs(worldData.tilesets or {}) do
    self.tilesets[tileset.numericId] = tileset
  end
  for _, sprite in ipairs(worldData.sprites or {}) do
    self.sprites[sprite.id] = sprite
  end
  for _, roof in ipairs(worldData.roofs or {}) do
    self.roofs[roof.group] = roof
  end
  return self
end

function MapRepository:getMap(id)
  return self.maps[id]
end

function MapRepository:getTileset(id)
  return self.tilesets[id]
end

function MapRepository:getSprite(id)
  return self.sprites[id]
end

function MapRepository:getRoof(group)
  return self.roofs[group]
end

return MapRepository
