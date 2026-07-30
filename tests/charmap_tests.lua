return function(test, equal, truthy, raises)
  local Charmap = require("src.import.Charmap")

  test("Charmap decodes English glyphs and ligatures", function()
    local data = string.char(
      0x8f, 0xae, 0xaa, 0xea, 0xac, 0xae, 0xad, 0x50
    )
    equal(Charmap.decodePlain(data), "Pokémon")
  end)

  test("Charmap distinguishes controls, unknowns, and terminators",
    function()
      local units = Charmap.decode(string.char(0x4f, 0x17, 0x50, 0x80))
      equal(#units, 3)
      equal(units[1].kind, "control")
      equal(units[1].name, "LINE")
      equal(units[2].kind, "unknown")
      equal(units[2].byte, 0x17)
      equal(units[3].kind, "terminator")
    end)

  test("Charmap preserves runtime substitutions as controls", function()
    local units = Charmap.decode(string.char(0x52, 0x7f, 0x54, 0x50))
    equal(units[1].kind, "control")
    equal(units[1].name, "PLAYER")
    equal(units[2].text, " ")
    equal(units[3].kind, "control")
    equal(units[3].name, "POKE_NAME")
  end)

  test("Charmap plain decoding refuses behavioral control bytes", function()
    raises(function()
      Charmap.decodePlain(string.char(0x80, 0x4f, 0x50))
    end, "control")
    raises(function() Charmap.lookup(-1) end, "0 to 255")
    truthy(Charmap.lookup(0xef).text == "♂")
  end)
end
