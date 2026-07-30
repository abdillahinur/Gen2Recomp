local CrystalIntroRenderer = {}
CrystalIntroRenderer.__index = CrystalIntroRenderer

local function rgb(color)
  local value = color.rgb8
  return value[1] / 255, value[2] / 255, value[3] / 255
end

local function makeImage(graphics, image, picture)
  local width = picture.widthTiles * 8
  local height = picture.heightTiles * 8
  local data = image.newImageData(width, height)
  for tileIndex, pixels in ipairs(picture.tiles) do
    local tileX = (tileIndex - 1) % picture.widthTiles * 8
    local tileY = math.floor((tileIndex - 1) / picture.widthTiles) * 8
    for y = 0, 7 do
      for x = 0, 7 do
        local value = pixels[y * 8 + x + 1]
        local r, g, b = rgb(picture.palette.colors[value + 1])
        data:setPixel(tileX + x, tileY + y, r, g, b, 1)
      end
    end
  end
  local result = graphics.newImage(data)
  result:setFilter("nearest", "nearest")
  return result
end

local function makeClockTile(graphics, image, pixels)
  local data = image.newImageData(8, 8)
  for y = 0, 7 do
    for x = 0, 7 do
      local ink = pixels[y * 8 + x + 1] ~= 0
      local value = ink and 0 or 1
      data:setPixel(x, y, value, value, value, 1)
    end
  end
  local result = graphics.newImage(data)
  result:setFilter("nearest", "nearest")
  result:setWrap("repeat", "repeat")
  return result
end

function CrystalIntroRenderer.new(data, dependencies)
  if type(data) ~= "table" or data.schema ~= 1 then
    error("Crystal intro renderer requires decoded schema 1", 2)
  end
  dependencies = dependencies or {}
  local graphics = dependencies.graphics or love.graphics
  local image = dependencies.image or love.image
  local pictures = {}
  for id, picture in pairs(data.pictures) do
    pictures[id] = makeImage(graphics, image, picture)
  end
  return setmetatable({
    graphics = graphics,
    pictures = pictures,
    background = makeClockTile(graphics, image, data.clock.background),
    up = makeClockTile(graphics, image, data.clock.up),
    down = makeClockTile(graphics, image, data.clock.down),
  }, CrystalIntroRenderer)
end

function CrystalIntroRenderer:drawClockBackground()
  local g = self.graphics
  g.setColor(1, 1, 1, 1)
  local quad = g.newQuad(0, 0, 160, 144, 8, 8)
  g.draw(self.background, quad, 0, 0)
end

function CrystalIntroRenderer:drawClockArrows(x, y)
  local g = self.graphics
  g.setColor(1, 1, 1, 1)
  g.draw(self.up, x, y - 8)
  g.draw(self.down, x, y + 16)
end

function CrystalIntroRenderer:drawPicture(id, options)
  options = options or {}
  local picture = self.pictures[id]
  if not picture then return false end
  local width, height = picture:getDimensions()
  local x = options.x or math.floor((160 - width) / 2)
  local y = options.y or (88 - height)
  local reveal = options.reveal or 1
  self.graphics.setColor(1, 1, 1, options.alpha or 1)
  if reveal < 1 then
    self.graphics.setScissor(x, y, math.floor(width * reveal), height)
  end
  self.graphics.draw(picture, x, y)
  if reveal < 1 then self.graphics.setScissor() end
  return true
end

return CrystalIntroRenderer
