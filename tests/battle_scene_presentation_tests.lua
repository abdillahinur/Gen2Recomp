return function(test, equal, truthy, raises)
  local BattleLayout = require("src.battle.BattleLayout")
  local BattleSceneRenderer = require("src.render.BattleSceneRenderer")
  local BattleSceneState = require("src.states.BattleSceneState")
  local CrystalBattlePics = require("src.import.CrystalBattlePics")

  test("Crystal battle layout matches declared pret tile anchors", function()
    equal(BattleLayout.enemy.pic.xTiles, 12)
    equal(BattleLayout.enemy.pic.yTiles, 0)
    equal(BattleLayout.enemy.pic.widthTiles, 7)
    equal(BattleLayout.player.pic.xTiles, 2)
    equal(BattleLayout.player.pic.yTiles, 6)
    equal(BattleLayout.player.pic.widthTiles, 6)
    equal(BattleLayout.enemy.hud.hpBar.xTiles, 2)
    equal(BattleLayout.enemy.hud.hpBar.yTiles, 2)
    equal(BattleLayout.player.hud.hpBar.xTiles, 10)
    equal(BattleLayout.player.hud.hpBar.yTiles, 9)
    local x, y = BattleLayout.tilesToPixels(12, 0)
    equal(x, 96)
    equal(y, 0)
  end)

  test("CrystalBattlePics maps dba_pic banks through PICS_FIX", function()
    equal(CrystalBattlePics.PICS_FIX, 0x36)
    equal(CrystalBattlePics.fixPicBank(0x1f), 0x55)
    equal(CrystalBattlePics.fixPicBank(0x12), 0x48)
  end)

  test("CrystalBattlePics front pad offsets match PadFrontpic", function()
    local x7, y7 = CrystalBattlePics.frontPadOffset(7, 7)
    equal(x7, 0)
    equal(y7, 0)
    local x6, y6 = CrystalBattlePics.frontPadOffset(6, 6)
    equal(x6, 1)
    equal(y6, 1)
    local x5, y5 = CrystalBattlePics.frontPadOffset(5, 5)
    equal(x5, 1)
    equal(y5, 2)
  end)

  test("CrystalBattlePics parses semantic species numbers", function()
    equal(
      CrystalBattlePics.speciesNumber("crystal.species.016.pidgey"),
      16
    )
    equal(
      CrystalBattlePics.speciesNumber("crystal.species.152.cyndaquil"),
      152
    )
    equal(CrystalBattlePics.speciesNumber("hero"), nil)
  end)

  local function blankTile()
    local pixels = {}
    for index = 1, 64 do pixels[index] = 0 end
    return pixels
  end

  local function solidTile(value)
    local pixels = {}
    for index = 1, 64 do pixels[index] = value end
    return pixels
  end

  local function palette()
    return {
      colors = {
        { rgb8 = { 255, 255, 255 } },
        { rgb8 = { 200, 100, 50 } },
        { rgb8 = { 100, 50, 25 } },
        { rgb8 = { 0, 0, 0 } },
      },
    }
  end

  local function picture(width, height, fill)
    local tiles = {}
    for index = 1, width * height do
      tiles[index] = solidTile(fill or 1)
    end
    return {
      widthTiles = width,
      heightTiles = height,
      tiles = tiles,
      palette = palette(),
      shinyPalette = palette(),
    }
  end

  test("BattleSceneRenderer draws ROM pics at Crystal anchors", function()
    local draws = {}
    local graphics = {
      setColor = function() end,
      rectangle = function() end,
      ellipse = function() end,
      circle = function() end,
      print = function() end,
      printf = function() end,
      draw = function(image, x, y)
        draws[#draws + 1] = { image = image, x = x, y = y }
      end,
    }
    local imageApi = {
      newImageData = function(width, height)
        return {
          width = width,
          height = height,
          setPixel = function() end,
        }
      end,
    }
    local fakeImage = {
      setFilter = function() end,
      getDimensions = function() return 48, 48 end,
    }
    graphics.newImage = function()
      return fakeImage
    end

    local renderer = BattleSceneRenderer.new({
      schema = 1,
      species = {
        [16] = {
          number = 16,
          front = picture(5, 5, 1),
          back = picture(6, 6, 2),
        },
        [152] = {
          number = 152,
          front = picture(5, 5, 1),
          back = picture(6, 6, 2),
        },
      },
      player = {
        male = picture(6, 6, 3),
        female = picture(6, 6, 3),
      },
    }, {
      graphics = graphics,
      image = imageApi,
    })

    local session = {
      state = {
        opponent = {
          active = function()
            return {
              speciesId = "crystal.species.016.pidgey",
              nickname = "PIDGEY",
              level = 2,
              currentHP = 10,
              stats = { hp = 10 },
            }
          end,
        },
        player = {
          active = function()
            return {
              speciesId = "crystal.species.152.cyndaquil",
              nickname = "CYNDAQUIL",
              level = 5,
              currentHP = 20,
              stats = { hp = 20 },
            }
          end,
        },
      },
    }

    renderer:draw(session)
    truthy(#draws >= 2)
    equal(draws[1].x, 96 + 8) -- enemy front pad (1,2) for 5x5
    equal(draws[1].y, 0 + 16)
    equal(draws[2].x, 16) -- player back at hlcoord 2,6
    equal(draws[2].y, 48)
  end)

  test("BattleSceneState uses renderer when battle pics are supplied", function()
    local drawn = false
    local renderer = {
      draw = function() drawn = true end,
    }
    local BattlePresentation = require("src.ui.BattlePresentation")
    local session = {
      command = function() end,
      state = {
        kind = "wild",
        events = {},
        phase = "command",
        opponent = {
          active = function()
            return {
              speciesId = "crystal.species.016.pidgey",
              nickname = "PIDGEY",
              level = 2,
              currentHP = 10,
              stats = { hp = 10 },
              moves = {},
            }
          end,
        },
        player = {
          active = function()
            return {
              speciesId = "crystal.species.152.cyndaquil",
              nickname = "CYNDAQUIL",
              level = 5,
              currentHP = 20,
              stats = { hp = 20 },
              moves = {},
            }
          end,
        },
      },
      registry = {
        get = function()
          return { name = "TAP", type = "normal", pp = 10 }
        end,
      },
    }
    local state = BattleSceneState.new(session, {
      renderer = renderer,
    })
    -- Avoid love.graphics in headless tests: presentation still draws.
    local presentationDraw = state.presentation.draw
    state.presentation.draw = function() end
    state:draw()
    state.presentation.draw = presentationDraw
    truthy(drawn)
  end)
end
