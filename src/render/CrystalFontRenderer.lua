local CrystalFontRenderer = {}
CrystalFontRenderer.__index = CrystalFontRenderer

local CODE_BY_ASCII = {
  [" "] = 0x7f,
  ["("] = 0x9a,
  [")"] = 0x9b,
  [":"] = 0x9c,
  [";"] = 0x9d,
  ["["] = 0x9e,
  ["]"] = 0x9f,
  ["'"] = 0xe0,
  ["-"] = 0xe3,
  ["?"] = 0xe6,
  ["!"] = 0xe7,
  ["."] = 0xe8,
  ["&"] = 0xe9,
  ["/"] = 0xf3,
  [","] = 0xf4,
}

for index = 0, 25 do
  CODE_BY_ASCII[string.char(string.byte("A") + index)] = 0x80 + index
  CODE_BY_ASCII[string.char(string.byte("a") + index)] = 0xa0 + index
end
for index = 0, 9 do
  CODE_BY_ASCII[tostring(index)] = 0xf6 + index
end

local function mainSet(font)
  for _, set in ipairs(font.sets or {}) do
    if set.id == "main" then return set end
  end
  error("Crystal font renderer requires the main font set", 3)
end

local function buildAtlas(graphics, image, font)
  local set = mainSet(font)
  local data = image.newImageData(16 * 8, 8 * 8)
  for tileIndex, pixels in ipairs(set.tiles) do
    local tileX = (tileIndex - 1) % 16 * 8
    local tileY = math.floor((tileIndex - 1) / 16) * 8
    for y = 0, 7 do
      for x = 0, 7 do
        local ink = pixels[y * 8 + x + 1] ~= 0
        data:setPixel(tileX + x, tileY + y, 0, 0, 0, ink and 1 or 0)
      end
    end
  end
  local atlas = graphics.newImage(data)
  atlas:setFilter("nearest", "nearest")
  return atlas
end

function CrystalFontRenderer.new(font, dependencies)
  if type(font) ~= "table" or font.schema ~= 1 then
    error("Crystal font renderer requires decoded font schema 1", 2)
  end
  dependencies = dependencies or {}
  local graphics = dependencies.graphics or love.graphics
  local image = dependencies.image or love.image
  return setmetatable({
    font = font,
    graphics = graphics,
    atlas = buildAtlas(graphics, image, font),
    quads = {},
  }, CrystalFontRenderer)
end

function CrystalFontRenderer:_quad(code)
  if code < 0x80 or code > 0xff then return nil end
  if not self.quads[code] then
    local index = code - 0x80
    self.quads[code] = self.graphics.newQuad(
      index % 16 * 8,
      math.floor(index / 16) * 8,
      8,
      8,
      self.atlas:getDimensions()
    )
  end
  return self.quads[code]
end

function CrystalFontRenderer:drawText(text, x, y, options)
  options = options or {}
  local startX = x
  local spacing = options.spacing or 8
  local lineHeight = options.lineHeight or 16
  local maximumColumns = options.maximumColumns
  local column = 0
  self.graphics.setColor(1, 1, 1, 1)
  for index = 1, #text do
    local character = text:sub(index, index)
    if character == "\n" then
      x = startX
      y = y + lineHeight
      column = 0
    else
      local code = CODE_BY_ASCII[character] or 0xe6
      local quad = self:_quad(code)
      if quad then self.graphics.draw(self.atlas, quad, x, y) end
      x = x + spacing
      column = column + 1
      if maximumColumns and column >= maximumColumns then
        x = startX
        y = y + lineHeight
        column = 0
      end
    end
  end
end

function CrystalFontRenderer:drawBox(x, y, width, height)
  local g = self.graphics
  g.setColor(1, 1, 1, 1)
  g.rectangle("fill", x, y, width, height)
  g.setColor(0, 0, 0, 1)
  g.rectangle("line", x, y, width - 1, height - 1)
  g.rectangle("line", x + 2, y + 2, width - 5, height - 5)
end

function CrystalFontRenderer:drawPrompt()
  local g = self.graphics
  g.setColor(0, 0, 0, 1)
  g.polygon("fill", 144, 132, 150, 132, 147, 136)
end

function CrystalFontRenderer:drawDialogue(text, prompt)
  self:drawBox(0, 96, 160, 48)
  self:drawText(text or "", 8, 104, {
    maximumColumns = 18,
    lineHeight = 16,
  })
  if prompt then self:drawPrompt() end
end

return CrystalFontRenderer
