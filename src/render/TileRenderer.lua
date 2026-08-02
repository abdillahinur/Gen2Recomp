local OverworldSpriteAnimator =
  require("src.render.OverworldSpriteAnimator")

local TileRenderer = {}
TileRenderer.__index = TileRenderer

local ATLAS_COLUMNS = 16
local TILE_SIZE = 8

local function rgb(color)
  local value = color.rgb8
  return value[1] / 255, value[2] / 255, value[3] / 255
end

local function roofColor(roof, period, colorIndex)
  if not roof or colorIndex < 1 or colorIndex > 2 then
    return nil
  end
  local set = (period == "night" or period == "dark")
    and roof.palettes.night or roof.palettes.morningDay
  return set and set.colors[colorIndex]
end

local function backgroundColor(
    tileset,
    roof,
    period,
    paletteId,
    colorId)
  local palettes = tileset.palettes.timeOfDay[period]
  local palette = palettes and palettes[paletteId + 1]
  local color = palette and palette.colors[colorId + 1]
  if paletteId == 6 and (colorId == 1 or colorId == 2) then
    color = roofColor(roof, period, colorId)
  end
  return color
end

local function tilePixels(tileset, roof, encodedTileId)
  if roof and encodedTileId >= 10 and encodedTileId < 19 then
    return roof.tiles[encodedTileId - 10 + 1]
  end
  local slot = tileset.tileSlots[encodedTileId + 1]
  local index = slot and slot.graphicIndex
  if type(index) ~= "number" then
    return nil
  end
  return tileset.graphics.tiles[index + 1]
end

function TileRenderer.new(repository, worldData, timeProvider)
  return setmetatable({
    repository = repository,
    worldData = worldData,
    timeProvider = timeProvider,
    tileAtlases = {},
    spriteImages = {},
  }, TileRenderer)
end

function TileRenderer:tileAtlas(tileset, roof, period)
  local key = table.concat({
    tostring(tileset.numericId),
    tostring(roof and roof.group or -1),
    period,
  }, ":")
  if self.tileAtlases[key] then
    return self.tileAtlases[key]
  end

  local rows = math.ceil(#tileset.tileSlots / ATLAS_COLUMNS)
  local imageData = love.image.newImageData(
    ATLAS_COLUMNS * TILE_SIZE,
    rows * TILE_SIZE
  )
  for encodedTileId = 0, #tileset.tileSlots - 1 do
    local slot = tileset.tileSlots[encodedTileId + 1]
    local pixels = tilePixels(tileset, roof, encodedTileId)
    local tileX = encodedTileId % ATLAS_COLUMNS * TILE_SIZE
    local tileY = math.floor(encodedTileId / ATLAS_COLUMNS) * TILE_SIZE
    for y = 0, 7 do
      for x = 0, 7 do
        local colorId = pixels and pixels[y * 8 + x + 1] or 0
        local color = backgroundColor(
          tileset,
          roof,
          period,
          slot.paletteId,
          colorId
        )
        local red, green, blue = rgb(color)
        imageData:setPixel(tileX + x, tileY + y, red, green, blue, 1)
      end
    end
  end

  local image = love.graphics.newImage(imageData)
  image:setFilter("nearest", "nearest")
  local quads = {}
  for id = 0, #tileset.tileSlots - 1 do
    quads[id] = love.graphics.newQuad(
      id % ATLAS_COLUMNS * TILE_SIZE,
      math.floor(id / ATLAS_COLUMNS) * TILE_SIZE,
      TILE_SIZE,
      TILE_SIZE,
      image:getDimensions()
    )
  end
  local atlas = { image = image, quads = quads }
  self.tileAtlases[key] = atlas
  return atlas
end

function TileRenderer:spriteImage(sprite, paletteId, period)
  local key = table.concat({
    tostring(sprite.id),
    tostring(paletteId),
    period,
  }, ":")
  if self.spriteImages[key] then
    return self.spriteImages[key]
  end

  local paletteSet = self.worldData.objectPalettes[period]
  local palette = paletteSet[paletteId + 1]
  local rows = math.ceil(sprite.tileCount / 2)
  local imageData = love.image.newImageData(16, rows * 8)
  for tileIndex, pixels in ipairs(sprite.tiles) do
    local tileX = (tileIndex - 1) % 2 * 8
    local tileY = math.floor((tileIndex - 1) / 2) * 8
    for y = 0, 7 do
      for x = 0, 7 do
        local colorId = pixels[y * 8 + x + 1]
        local color = palette.colors[colorId + 1]
        local red, green, blue = rgb(color)
        imageData:setPixel(
          tileX + x,
          tileY + y,
          red,
          green,
          blue,
          colorId == 0 and 0 or 1
        )
      end
    end
  end
  local image = love.graphics.newImage(imageData)
  image:setFilter("nearest", "nearest")
  self.spriteImages[key] = image
  return image
end

function TileRenderer:drawMap(world, period)
  local map = world.currentMap
  local tileset = self.repository:getTileset(map.tilesetId)
  local roof = self.repository:getRoof(map.group)
  local atlas = self:tileAtlas(tileset, roof, period)
  local camera = world.camera
  local firstX = math.max(0, math.floor(camera.x / 8))
  local firstY = math.max(0, math.floor(camera.y / 8))
  local lastX = math.min(world.grid.widthTiles - 1, firstX + 20)
  local lastY = math.min(world.grid.heightTiles - 1, firstY + 18)
  love.graphics.setColor(1, 1, 1, 1)
  for y = firstY, lastY do
    for x = firstX, lastX do
      local id = world.grid:tileAt(x, y)
      love.graphics.draw(
        atlas.image,
        atlas.quads[id],
        x * 8 - camera.x,
        y * 8 - camera.y
      )
    end
  end
end

function TileRenderer:drawSprite(
    spriteId,
    x,
    y,
    facing,
    overridePalette,
    period,
    camera,
    anim)
  local sprite = self.repository:getSprite(spriteId)
  if not sprite then
    return
  end
  local paletteId = overridePalette and overridePalette >= 8
    and overridePalette - 8 or sprite.defaultPaletteId
  local image = self:spriteImage(sprite, paletteId, period)
  local selection = OverworldSpriteAnimator.select({
    tileCount = sprite.tileCount,
    kind = sprite.kind,
    facing = facing,
    moving = anim and anim.moving,
    phase = anim and anim.phase or 0,
  })
  local frame = selection.frame
  local flip = selection.flipX
  local quad = love.graphics.newQuad(
    0,
    frame * 16,
    16,
    16,
    image:getDimensions()
  )
  local drawX = math.floor(x - camera.x)
  local drawY = math.floor(y - camera.y)
  love.graphics.setColor(1, 1, 1, 1)
  if flip then
    love.graphics.draw(image, quad, drawX + 16, drawY, 0, -1, 1)
  else
    love.graphics.draw(image, quad, drawX, drawY)
  end
end

function TileRenderer:drawObjects(world, period)
  local entries = {}
  for _, object in ipairs(world:currentObjects()) do
    if object.visible then
      entries[#entries + 1] = {
        spriteId = object.spriteId,
        x = object.pixelX,
        y = object.pixelY,
        facing = object.facing,
        paletteId = object.paletteId,
        player = false,
        moving = object.moving ~= nil,
        phase = object.animPhase or 0,
        order = #entries + 1,
      }
    end
  end
  entries[#entries + 1] = {
    spriteId = world.player.spriteId,
    x = world.player.pixelX,
    y = world.player.pixelY,
    facing = world.player.facing,
    player = true,
    moving = world.player.moving ~= nil,
    phase = world.player.animPhase or 0,
    order = #entries + 1,
  }
  table.sort(entries, function(left, right)
    if left.y == right.y then
      return left.order < right.order
    end
    return left.y < right.y
  end)
  for _, entry in ipairs(entries) do
    self:drawSprite(
      entry.spriteId,
      entry.x,
      entry.y,
      entry.facing,
      entry.paletteId,
      period,
      world.camera,
      { moving = entry.moving, phase = entry.phase }
    )
  end
  for _, object in ipairs(world:currentObjects()) do
    if object.visible and object.emote == "shock" then
      local x = math.floor(object.pixelX - world.camera.x) + 5
      local y = math.floor(object.pixelY - world.camera.y) - 10
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", x, y, 7, 9)
      love.graphics.setColor(0.08, 0.08, 0.08, 1)
      love.graphics.rectangle("fill", x + 3, y + 2, 1, 4)
      love.graphics.rectangle("fill", x + 3, y + 7, 1, 1)
    end
  end
end

function TileRenderer:draw(world)
  local period =
    self.timeProvider:forMap(world.currentMap.paletteModeId)
  self:drawMap(world, period)
  self:drawObjects(world, period)
end

return TileRenderer
