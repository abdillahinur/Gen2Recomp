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

  test("CrystalBattlePics extracts synthetic ROM pointers and palettes", function()
    local bytes = {}
    local blobs = {}
    local offsetCalls = {}
    local function put(offset, ...)
      for index, value in ipairs({ ... }) do
        bytes[offset + index - 1] = value
      end
    end
    local function putWord(offset, value)
      put(offset, value % 0x100, math.floor(value / 0x100))
    end
    local function tile(value)
      local low = value % 2 == 1 and 0xff or 0
      local high = value >= 2 and 0xff or 0
      return string.rep(string.char(low, high), 8)
    end
    local function literalLz(raw)
      local chunks = {}
      for first = 1, #raw, 32 do
        local chunk = raw:sub(first, math.min(first + 31, #raw))
        chunks[#chunks + 1] = string.char(#chunk - 1)
        chunks[#chunks + 1] = chunk
      end
      chunks[#chunks + 1] = string.char(0xff)
      return table.concat(chunks)
    end
    local function bankOffset(bank, address)
      return bank * 0x4000 + address - 0x4000
    end

    local profile = { symbols = {
      PokemonPicPointers = { offset = 0x0100 },
      BaseData = { offset = 0x0400 },
      PokemonPalettes = { offset = 0x0800 },
      TrainerPalettes = { offset = 0x0c00 },
      ChrisBackpic = { offset = 0x8000 },
      KrisBackpic = { offset = 0xc100 },
    } }
    put(0x0106, 0x12)
    putWord(0x0107, 0x4100)
    put(0x0109, 0x13)
    putWord(0x010a, 0x4200)
    put(0x0400 + 32 + 17, 0x22)
    put(0x0810, 0x1f, 0x00, 0xe0, 0x03,
      0x00, 0x7c, 0x10, 0x42)
    put(0x0c00, 0x1f, 0x00, 0xe0, 0x03)
    put(0x0c04, 0x00, 0x7c, 0x10, 0x42)
    blobs[bankOffset(0x48, 0x4100)] =
      literalLz(tile(0) .. tile(1) .. tile(2) .. tile(3))
    blobs[bankOffset(0x49, 0x4200)] =
      literalLz(string.rep(tile(1), 36))
    blobs[0x8000] = literalLz(string.rep(tile(2), 36))
    blobs[0xc100] = string.rep(tile(3), 36)

    local rom = {}
    function rom:readByte(offset)
      local value = bytes[offset]
      if value == nil then error("unexpected synthetic ROM byte read") end
      return value
    end
    function rom:readWord(offset)
      return self:readByte(offset) + self:readByte(offset + 1) * 0x100
    end
    function rom:readString(offset, length)
      local blob = blobs[offset]
      if blob then
        if offset == 0xc100 then
          equal(length, 36 * 16)
          return blob
        end
        equal(length, 0x4000 - offset % 0x4000)
        return blob .. string.rep("\0", length - #blob)
      end
      local result = {}
      for index = 0, length - 1 do
        result[index + 1] = string.char(self:readByte(offset + index))
      end
      return table.concat(result)
    end
    function rom:offset(bank, address, length)
      offsetCalls[#offsetCalls + 1] = { bank, address, length }
      return bankOffset(bank, address)
    end

    local got = CrystalBattlePics.extract(rom, profile, { species = { 2 } })
    equal(got.schema, 1)
    equal(got.layout, "crystal.battle.layout.v1")
    equal(got.count, 251)
    equal(got.species[1], nil)
    equal(got.species[2].number, 2)
    local front = got.species[2].front
    equal(front.widthTiles, 2)
    equal(front.heightTiles, 2)
    equal(#front.tiles, 4)
    equal(front.tiles[1][1], 0)
    equal(front.tiles[2][1], 2)
    equal(front.tiles[3][1], 1)
    equal(front.tiles[4][64], 3)
    equal(got.species[2].back.tiles[36][64], 1)
    equal(got.player.male.tiles[36][64], 2)
    equal(got.player.female.tiles[36][64], 3)
    equal(front.palette.colors[2].bgr15, 0x001f)
    equal(front.palette.colors[3].bgr15, 0x03e0)
    equal(front.shinyPalette.colors[2].bgr15, 0x7c00)
    equal(front.shinyPalette.colors[3].bgr15, 0x4210)
    equal(got.player.male.palette.colors[2].bgr15, 0x001f)
    equal(got.player.female.palette.colors[2].bgr15, 0x7c00)
    equal(offsetCalls[1][1], 0x48)
    equal(offsetCalls[1][2], 0x4100)
    equal(offsetCalls[2][1], 0x49)
    equal(offsetCalls[2][2], 0x4200)
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
