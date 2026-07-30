local Charmap = {}

local glyphs = {}
local controls = {
  [0x00] = "NULL",
  [0x14] = "PLAY_G",
  [0x15] = "MOBILE",
  [0x16] = "CR",
  [0x1f] = "BSP",
  [0x22] = "LF",
  [0x24] = "POKE",
  [0x25] = "WBR",
  [0x38] = "RED",
  [0x39] = "GREEN",
  [0x3f] = "ENEMY",
  [0x49] = "MOM",
  [0x4a] = "PKMN",
  [0x4b] = "_CONT",
  [0x4c] = "SCROLL",
  [0x4e] = "NEXT",
  [0x4f] = "LINE",
  [0x51] = "PARA",
  [0x52] = "PLAYER",
  [0x53] = "RIVAL",
  [0x54] = "POKE_NAME",
  [0x55] = "CONT",
  [0x56] = "SIX_DOTS",
  [0x57] = "DONE",
  [0x58] = "PROMPT",
  [0x59] = "TARGET",
  [0x5a] = "USER",
  [0x5b] = "PC",
  [0x5c] = "TM",
  [0x5d] = "TRAINER",
  [0x5e] = "ROCKET",
  [0x5f] = "DEXEND",
}

for index = 0, 25 do
  glyphs[0x80 + index] = string.char(string.byte("A") + index)
  glyphs[0xa0 + index] = string.char(string.byte("a") + index)
end
for index = 0, 9 do
  glyphs[0xf6 + index] = tostring(index)
end

local literalGlyphs = {
  [0x60] = "A",
  [0x61] = "B",
  [0x62] = "C",
  [0x63] = "D",
  [0x64] = "E",
  [0x65] = "F",
  [0x66] = "G",
  [0x67] = "H",
  [0x68] = "I",
  [0x69] = "V",
  [0x6a] = "S",
  [0x6b] = "L",
  [0x6c] = "M",
  [0x6d] = ":",
  [0x70] = "PO",
  [0x71] = "KE",
  [0x72] = "“",
  [0x73] = "”",
  [0x74] = "·",
  [0x75] = "…",
  [0x79] = "┌",
  [0x7a] = "─",
  [0x7b] = "┐",
  [0x7c] = "│",
  [0x7d] = "└",
  [0x7e] = "┘",
  [0x7f] = " ",
  [0x9a] = "(",
  [0x9b] = ")",
  [0x9c] = ":",
  [0x9d] = ";",
  [0x9e] = "[",
  [0x9f] = "]",
  [0xc0] = "Ä",
  [0xc1] = "Ö",
  [0xc2] = "Ü",
  [0xc3] = "ä",
  [0xc4] = "ö",
  [0xc5] = "ü",
  [0xd0] = "'d",
  [0xd1] = "'l",
  [0xd2] = "'m",
  [0xd3] = "'r",
  [0xd4] = "'s",
  [0xd5] = "'t",
  [0xd6] = "'v",
  [0xdf] = "←",
  [0xe0] = "'",
  [0xe1] = "PK",
  [0xe2] = "MN",
  [0xe3] = "-",
  [0xe6] = "?",
  [0xe7] = "!",
  [0xe8] = ".",
  [0xe9] = "&",
  [0xea] = "é",
  [0xeb] = "→",
  [0xec] = "▷",
  [0xed] = "▶",
  [0xee] = "▼",
  [0xef] = "♂",
  [0xf0] = "¥",
  [0xf1] = "×",
  [0xf2] = ".",
  [0xf3] = "/",
  [0xf4] = ",",
  [0xf5] = "♀",
}
for byte, value in pairs(literalGlyphs) do
  glyphs[byte] = value
end

function Charmap.lookup(byte)
  if type(byte) ~= "number" or byte % 1 ~= 0 or byte < 0 or byte > 0xff then
    error("charmap byte must be an integer from 0 to 255", 2)
  end
  if byte == 0x50 then
    return { kind = "terminator" }
  end
  if glyphs[byte] then
    local unit = { kind = "glyph", text = glyphs[byte] }
    if byte >= 0x60 and byte <= 0x6d then
      unit.style = "bold"
    end
    return unit
  end
  if controls[byte] then
    return { kind = "control", name = controls[byte] }
  end
  return nil
end

function Charmap.decode(data, options)
  options = options or {}
  if type(data) ~= "string" then
    error("charmap data must be a binary string", 2)
  end

  local units = {}
  for index = 1, #data do
    local byte = data:byte(index)
    local unit = Charmap.lookup(byte)
    if not unit then
      unit = { kind = "unknown", byte = byte }
    end
    units[#units + 1] = unit
    if unit.kind == "terminator" and options.stopAtTerminator ~= false then
      break
    end
  end
  return units
end

function Charmap.decodePlain(data)
  local parts = {}
  for _, unit in ipairs(Charmap.decode(data)) do
    if unit.kind == "terminator" then
      return table.concat(parts)
    elseif unit.kind ~= "glyph" then
      error("plain charmap string contains " .. unit.kind, 2)
    end
    parts[#parts + 1] = unit.text
  end
  return table.concat(parts)
end

return Charmap
