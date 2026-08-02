local BattleLayout = require("src.battle.BattleLayout")
local CrystalBattlePics = require("src.import.CrystalBattlePics")

local BattleSceneRenderer = {}
BattleSceneRenderer.__index = BattleSceneRenderer

local function rgb(color)
  local value = color.rgb8
  return value[1] / 255, value[2] / 255, value[3] / 255
end

local function makeImage(graphics, image, picture, palette)
  palette = palette or picture.palette
  local width = picture.widthTiles * 8
  local height = picture.heightTiles * 8
  local data = image.newImageData(width, height)
  for tileIndex, pixels in ipairs(picture.tiles) do
    local tileX = (tileIndex - 1) % picture.widthTiles * 8
    local tileY = math.floor((tileIndex - 1) / picture.widthTiles) * 8
    for y = 0, 7 do
      for x = 0, 7 do
        local value = pixels[y * 8 + x + 1]
        local r, g, b = rgb(palette.colors[value + 1])
        -- Color 0 is treated as opaque battlefield fill by Crystal BG;
        -- keep it opaque so we do not punch holes through the scene.
        data:setPixel(tileX + x, tileY + y, r, g, b, 1)
      end
    end
  end
  local result = graphics.newImage(data)
  result:setFilter("nearest", "nearest")
  return result
end

local function cacheKey(number, face, shiny)
  return tostring(number) .. ":" .. face .. (shiny and ":shiny" or "")
end

function BattleSceneRenderer.new(data, dependencies)
  dependencies = dependencies or {}
  local graphics = dependencies.graphics or love.graphics
  local image = dependencies.image or love.image
  return setmetatable({
    data = data,
    graphics = graphics,
    image = image,
    cache = {},
  }, BattleSceneRenderer)
end

function BattleSceneRenderer:_pictureImage(picture, shiny)
  if type(picture) ~= "table" or type(picture.tiles) ~= "table" then
    return nil
  end
  local palette = shiny and picture.shinyPalette or picture.palette
  return makeImage(self.graphics, self.image, picture, palette)
end

function BattleSceneRenderer:_speciesImage(number, face, shiny)
  if not self.data or type(self.data.species) ~= "table" then
    return nil, nil
  end
  local record = self.data.species[number]
  if type(record) ~= "table" then return nil, nil end
  local picture = record[face]
  if type(picture) ~= "table" then return nil, nil end
  local key = cacheKey(number, face, shiny)
  if not self.cache[key] then
    self.cache[key] = self:_pictureImage(picture, shiny)
  end
  return self.cache[key], picture
end

function BattleSceneRenderer:_playerBack(gender)
  if not self.data or type(self.data.player) ~= "table" then
    return nil
  end
  local key = "player:" .. tostring(gender or "male")
  if not self.cache[key] then
    local picture = gender == "female"
      and self.data.player.female
      or self.data.player.male
    self.cache[key] = self:_pictureImage(picture, false)
  end
  return self.cache[key]
end

local function hpColor(ratio)
  local colors = BattleLayout.hp
  if ratio > 0.5 then return colors.green end
  if ratio > 0.2 then return colors.yellow end
  return colors.red
end

local function drawHpBar(g, x, y, width, pokemon)
  local ratio = 0
  if pokemon.stats and pokemon.stats.hp > 0 then
    ratio = pokemon.currentHP / pokemon.stats.hp
  end
  local track = BattleLayout.hp.track
  g.setColor(track.r, track.g, track.b, 1)
  g.rectangle("fill", x, y, width, 4)
  local fill = hpColor(ratio)
  g.setColor(fill.r, fill.g, fill.b, 1)
  g.rectangle("fill", x + 1, y + 1, math.floor((width - 2) * ratio), 2)
end

local function drawHudPanel(g, x, y, width, height)
  g.setColor(0.97, 0.98, 0.92, 1)
  g.rectangle("fill", x, y, width, height)
  g.setColor(0.08, 0.1, 0.12, 1)
  g.rectangle("line", x, y, width - 1, height - 1)
  g.rectangle("line", x + 2, y + 2, width - 5, height - 5)
end

function BattleSceneRenderer:drawBackground()
  local g = self.graphics
  local fill = BattleLayout.background.fill
  local ground = BattleLayout.background.ground
  g.setColor(fill.r, fill.g, fill.b, 1)
  g.rectangle("fill", 0, 0, 160, 144)
  g.setColor(ground.r, ground.g, ground.b, 1)
  -- Soft ground ellipses under the Crystal pic anchors.
  local enemyX = BattleLayout.enemy.pic.xTiles * 8 + 28
  local enemyY = BattleLayout.enemy.pic.yTiles * 8 + 48
  local playerX = BattleLayout.player.pic.xTiles * 8 + 24
  local playerY = BattleLayout.player.pic.yTiles * 8 + 40
  g.ellipse("fill", enemyX, enemyY, 35, 8)
  g.ellipse("fill", playerX, playerY, 38, 9)
end

function BattleSceneRenderer:drawEnemy(pokemon)
  local g = self.graphics
  local number = CrystalBattlePics.speciesNumber(pokemon.speciesId)
  local image, picture = self:_speciesImage(
    number, "front", pokemon.shiny)
  local originX = BattleLayout.enemy.pic.xTiles * 8
  local originY = BattleLayout.enemy.pic.yTiles * 8
  if image and picture then
    local padX, padY = CrystalBattlePics.frontPadOffset(
      picture.widthTiles, picture.heightTiles)
    g.setColor(1, 1, 1, 1)
    g.draw(image, originX + padX * 8, originY + padY * 8)
  else
    g.setColor(0.2, 0.28, 0.34, 1)
    g.ellipse("fill", originX + 28, originY + 36, 20, 15)
    g.circle("fill", originX + 37, originY + 23, 10)
  end

  local hud = BattleLayout.enemy.hud
  local hx, hy = hud.clear.xTiles * 8, hud.clear.yTiles * 8
  drawHudPanel(g, hx, hy, hud.clear.widthTiles * 8, 28)
  g.setColor(0.08, 0.1, 0.12, 1)
  g.print(pokemon.nickname, hud.name.xTiles * 8, hud.name.yTiles * 8 + 1)
  g.printf(
    "L" .. pokemon.level,
    hud.level.xTiles * 8,
    hud.level.yTiles * 8,
    40,
    "left"
  )
  drawHpBar(
    g,
    hud.hpBar.xTiles * 8,
    hud.hpBar.yTiles * 8 + 2,
    hud.hpBar.widthTiles * 8,
    pokemon
  )
end

function BattleSceneRenderer:drawPlayer(pokemon, options)
  options = options or {}
  local g = self.graphics
  local originX = BattleLayout.player.pic.xTiles * 8
  local originY = BattleLayout.player.pic.yTiles * 8
  local number = CrystalBattlePics.speciesNumber(pokemon.speciesId)
  local image = self:_speciesImage(number, "back", pokemon.shiny)
  if not image and options.showTrainerBack then
    image = self:_playerBack(options.gender)
  end
  if image then
    g.setColor(1, 1, 1, 1)
    g.draw(image, originX, originY)
  else
    g.setColor(0.2, 0.28, 0.34, 1)
    g.ellipse("fill", originX + 24, originY + 30, 20, 15)
    g.circle("fill", originX + 15, originY + 17, 10)
  end

  local hud = BattleLayout.player.hud
  local hx, hy = hud.clear.xTiles * 8, hud.clear.yTiles * 8
  drawHudPanel(g, hx, hy, hud.clear.widthTiles * 8, 36)
  g.setColor(0.08, 0.1, 0.12, 1)
  g.print(pokemon.nickname, hud.name.xTiles * 8, hud.name.yTiles * 8 + 1)
  g.printf(
    "L" .. pokemon.level,
    hud.level.xTiles * 8,
    hud.level.yTiles * 8,
    24,
    "left"
  )
  drawHpBar(
    g,
    hud.hpBar.xTiles * 8,
    hud.hpBar.yTiles * 8 + 2,
    hud.hpBar.widthTiles * 8,
    pokemon
  )
  g.printf(
    pokemon.currentHP .. "/" .. pokemon.stats.hp,
    hud.hpText.xTiles * 8,
    hud.hpText.yTiles * 8,
    64,
    "right"
  )
end

function BattleSceneRenderer:draw(session, options)
  options = options or {}
  self:drawBackground()
  local state = session.state
  self:drawEnemy(state.opponent:active())
  self:drawPlayer(state.player:active(), options)
end

return BattleSceneRenderer
