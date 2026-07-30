return function(test, equal, truthy, raises)
  local CrystalFont = require("src.import.CrystalFont")
  local Rom = require("src.import.Rom")

  local profile = {
    symbols = {
      FontExtra = { offset = 0 },
      Font = { offset = 32 * 16 },
      FontBattleExtra = { offset = 32 * 16 + 128 * 8 },
      Frames = { offset = 32 * 16 + 128 * 8 + 32 * 16 },
    },
  }

  test("CrystalFont extracts all three normalized font sets", function()
    local size = profile.symbols.Frames.offset
    local data = string.char(0x80, 0x00) .. string.rep("\0", size - 2)
    local result = CrystalFont.extract(Rom.new(data), profile)

    equal(result.schema, 1)
    equal(#result.sets, 3)
    equal(result.sets[1].id, "extra")
    equal(result.sets[1].firstCode, 0x60)
    equal(#result.sets[1].tiles, 32)
    equal(result.sets[2].id, "main")
    equal(#result.sets[2].tiles, 128)
    equal(result.sets[3].id, "battle_extra")
    equal(#result.sets[3].tiles, 32)
    equal(result.sets[1].tiles[1][1], 1)
  end)

  test("CrystalFont rejects missing and structurally wrong profiles",
    function()
      raises(function()
        CrystalFont.extract(Rom.new(""), { symbols = {} })
      end, "missing symbol")

      local wrong = {
        symbols = {
          FontExtra = { offset = 0 },
          Font = { offset = 16 },
          FontBattleExtra = { offset = 24 },
          Frames = { offset = 40 },
        },
      }
      raises(function()
        CrystalFont.extract(Rom.new(string.rep("\0", 40)), wrong)
      end, "unexpected Crystal font")
      truthy(true)
    end)
end
