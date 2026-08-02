-- Declared Crystal battle presentation frames.
-- Source: pret/pokecrystal 3438c7003a57fa2987fcb223d14b660761b33c64
--   engine/battle/core.asm (DrawEnemyHUD / DrawPlayerHUD / InitBattleDisplay)
--   engine/gfx/load_pics.asm (front pad 7x7, back 6x6)
-- Coordinates are hlcoord tile units; pixels = tiles * 8.

local BattleLayout = {
  screen = { width = 160, height = 144 },
  textbox = {
    xTiles = 0,
    yTiles = 12,
    widthTiles = 20,
    heightTiles = 6,
  },
  enemy = {
    pic = {
      xTiles = 12,
      yTiles = 0,
      widthTiles = 7,
      heightTiles = 7,
    },
    hud = {
      clear = { xTiles = 1, yTiles = 0, widthTiles = 11, heightTiles = 4 },
      name = { xTiles = 1, yTiles = 0 },
      level = { xTiles = 6, yTiles = 1 },
      gender = { xTiles = 9, yTiles = 1 },
      hpBar = { xTiles = 2, yTiles = 2, widthTiles = 8 },
    },
  },
  player = {
    pic = {
      xTiles = 2,
      yTiles = 6,
      widthTiles = 6,
      heightTiles = 6,
    },
    hud = {
      clear = { xTiles = 9, yTiles = 7, widthTiles = 11, heightTiles = 5 },
      name = { xTiles = 10, yTiles = 7 },
      level = { xTiles = 14, yTiles = 8 },
      gender = { xTiles = 17, yTiles = 8 },
      hpBar = { xTiles = 10, yTiles = 9, widthTiles = 8 },
      hpText = { xTiles = 10, yTiles = 10 },
      expBar = { xTiles = 10, yTiles = 11, widthTiles = 8 },
    },
  },
  background = {
    -- Approximate battlefield fill used until terrain tiles are imported.
    fill = { r = 0.97, g = 0.98, b = 0.92 },
    ground = { r = 0.78, g = 0.84, b = 0.72 },
  },
  hp = {
    green = { r = 0.22, g = 0.72, b = 0.32 },
    yellow = { r = 0.9, g = 0.68, b = 0.18 },
    red = { r = 0.85, g = 0.22, b = 0.2 },
    track = { r = 0.12, g = 0.15, b = 0.16 },
  },
}

function BattleLayout.tilesToPixels(xTiles, yTiles)
  return xTiles * 8, yTiles * 8
end

return BattleLayout
