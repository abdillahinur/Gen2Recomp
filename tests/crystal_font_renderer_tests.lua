return function(test, equal)
  local Charmap = require("src.import.Charmap")
  local CrystalFontRenderer = require("src.render.CrystalFontRenderer")

  local function fixture()
    local draws = {}
    local graphics = {}
    function graphics.newImage()
      return {
        setFilter = function() end,
        getDimensions = function() return 128, 64 end,
      }
    end
    function graphics.newQuad(x, y)
      return { code = 0x80 + x / 8 + y / 8 * 16 }
    end
    function graphics.setColor() end
    function graphics.draw(_, quad, x, y)
      draws[#draws + 1] = { code = quad.code, x = x, y = y }
    end

    local image = {}
    function image.newImageData()
      return { setPixel = function() end }
    end

    local tiles = {}
    for index = 1, 128 do
      tiles[index] = {}
      for pixel = 1, 64 do tiles[index][pixel] = 0 end
    end
    local renderer = CrystalFontRenderer.new({
      schema = 1,
      sets = { { id = "main", tiles = tiles } },
    }, { graphics = graphics, image = image })
    return renderer, draws
  end

  test("Crystal font renderer draws decoded accented glyph once", function()
    local renderer, draws = fixture()
    local pokemon = Charmap.decodePlain(string.char(
      0x8f, 0xae, 0xaa, 0xea, 0xac, 0xae, 0xad, 0x50
    ))

    renderer:drawText(pokemon, 0, 0)

    equal(#draws, 7)
    equal(draws[4].code, 0xea)
    equal(draws[4].x, 24)
  end)

  test("Crystal font renderer wraps accented text by glyph", function()
    local renderer, draws = fixture()

    renderer:drawText("PokéAB", 0, 0, {
      maximumColumns = 5,
      lineHeight = 16,
    })

    equal(#draws, 6)
    equal(draws[5].code, 0x80)
    equal(draws[5].x, 32)
    equal(draws[5].y, 0)
    equal(draws[6].code, 0x81)
    equal(draws[6].x, 0)
    equal(draws[6].y, 16)
  end)

  test("Crystal font renderer preserves ASCII wrapping", function()
    local renderer, draws = fixture()

    renderer:drawText("PokeAB", 0, 0, {
      maximumColumns = 5,
      lineHeight = 16,
    })

    equal(#draws, 6)
    equal(draws[5].x, 32)
    equal(draws[5].y, 0)
    equal(draws[6].x, 0)
    equal(draws[6].y, 16)
  end)

  test("Crystal font renderer does not double-wrap explicit lines",
    function()
      local renderer, draws = fixture()

      renderer:drawText("12345\nA", 0, 0, {
        maximumColumns = 5,
        lineHeight = 16,
      })

      equal(#draws, 6)
      equal(draws[6].code, 0x80)
      equal(draws[6].x, 0)
      equal(draws[6].y, 16)
    end)
end
