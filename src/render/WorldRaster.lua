local WorldRaster = {}

local WIDTH = 160
local HEIGHT = 144

local function roofColor(roof, period, colorId)
  if not roof or (colorId ~= 1 and colorId ~= 2) then
    return nil
  end
  local set = (period == "night" or period == "dark")
    and roof.palettes.night or roof.palettes.morningDay
  return set.colors[colorId]
end

local function backgroundColor(
    tileset,
    roof,
    period,
    paletteId,
    colorId)
  local palette =
    tileset.palettes.timeOfDay[period][paletteId + 1]
  if paletteId == 6 and (colorId == 1 or colorId == 2) then
    return roofColor(roof, period, colorId)
      or palette.colors[colorId + 1]
  end
  return palette.colors[colorId + 1]
end

local function tilePixels(tileset, roof, encodedTileId)
  if roof and encodedTileId >= 10 and encodedTileId < 19 then
    return roof.tiles[encodedTileId - 9]
  end
  local slot = tileset.tileSlots[encodedTileId + 1]
  if not slot or type(slot.graphicIndex) ~= "number" then
    return nil
  end
  return tileset.graphics.tiles[slot.graphicIndex + 1]
end

local function setPixel(frame, x, y, color)
  if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT then
    return
  end
  frame[y * WIDTH + x + 1] = string.char(
    color.rgb8[1],
    color.rgb8[2],
    color.rgb8[3]
  )
end

local function drawBackground(frame, world, period)
  local map = world.currentMap
  local tileset = world.repository:getTileset(map.tilesetId)
  local roof = world.repository:getRoof(map.group)
  for screenY = 0, HEIGHT - 1 do
    local worldY = screenY + world.camera.y
    local tileY = math.floor(worldY / 8)
    local pixelY = worldY % 8
    for screenX = 0, WIDTH - 1 do
      local worldX = screenX + world.camera.x
      local tileX = math.floor(worldX / 8)
      local pixelX = worldX % 8
      local tileId = world.grid:tileAt(tileX, tileY)
      if tileId then
        local slot = tileset.tileSlots[tileId + 1]
        local pixels = tilePixels(tileset, roof, tileId)
        local colorId = pixels
          and pixels[pixelY * 8 + pixelX + 1] or 0
        setPixel(frame, screenX, screenY, backgroundColor(
          tileset,
          roof,
          period,
          slot.paletteId,
          colorId
        ))
      end
    end
  end
end

local function facingFrame(facing)
  if facing == "up" then
    return 1, false
  elseif facing == "left" then
    return 2, false
  elseif facing == "right" then
    return 2, true
  end
  return 0, false
end

local function drawSprite(
    frame,
    world,
    period,
    spriteId,
    pixelX,
    pixelY,
    facing,
    overridePalette)
  local sprite = world.repository:getSprite(spriteId)
  if not sprite then
    return
  end
  local paletteId = overridePalette and overridePalette >= 8
    and overridePalette - 8 or sprite.defaultPaletteId
  local palette =
    world.repository.data.objectPalettes[period][paletteId + 1]
  local facingIndex, flip = facingFrame(facing)
  if sprite.tileCount < 12 then
    facingIndex = 0
  end

  for y = 0, 15 do
    for x = 0, 15 do
      local sourceX = flip and 15 - x or x
      local tileColumn = math.floor(sourceX / 8)
      local tileRow = math.floor(y / 8)
      local tileIndex = facingIndex * 4
        + tileRow * 2 + tileColumn + 1
      local pixels = sprite.tiles[tileIndex]
      local colorId = pixels[
        (y % 8) * 8 + (sourceX % 8) + 1
      ]
      if colorId ~= 0 then
        setPixel(
          frame,
          math.floor(pixelX - world.camera.x) + x,
          math.floor(pixelY - world.camera.y) + y,
          palette.colors[colorId + 1]
        )
      end
    end
  end
end

local function drawObjects(frame, world, period)
  local entries = {}
  for _, object in ipairs(world.currentMap.objects or {}) do
    entries[#entries + 1] = {
      spriteId = object.spriteId,
      x = object.x * 16,
      y = object.y * 16,
      facing = "down",
      paletteId = object.paletteId,
      order = #entries + 1,
    }
  end
  entries[#entries + 1] = {
    spriteId = world.player.spriteId,
    x = world.player.pixelX,
    y = world.player.pixelY,
    facing = world.player.facing,
    order = #entries + 1,
  }
  table.sort(entries, function(left, right)
    if left.y == right.y then
      return left.order < right.order
    end
    return left.y < right.y
  end)
  for _, entry in ipairs(entries) do
    drawSprite(
      frame,
      world,
      period,
      entry.spriteId,
      entry.x,
      entry.y,
      entry.facing,
      entry.paletteId
    )
  end
end

function WorldRaster.render(world, period)
  local frame = {}
  local black = string.char(0, 0, 0)
  for index = 1, WIDTH * HEIGHT do
    frame[index] = black
  end
  drawBackground(frame, world, period)
  drawObjects(frame, world, period)
  return {
    width = WIDTH,
    height = HEIGHT,
    format = "rgb8",
    pixels = table.concat(frame),
  }
end

return WorldRaster
