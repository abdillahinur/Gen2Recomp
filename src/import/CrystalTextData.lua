local Charmap = require("src.import.Charmap")

local CrystalTextData = {}

local TX_START = 0x00
local TX_RAM = 0x01
local TX_PROMPT_BUTTON = 0x06
local TX_END = 0x50
local TEXT_TERMINALS = {
  [0x57] = "done",
  [0x58] = "prompt",
}
local MAX_ENTRY_BYTES = 4096

local CONTROL_TEXT = {
  POKE = "POKé",
  PKMN = "PKMN",
  POKE_NAME = "POKéMON",
  SIX_DOTS = "……",
  MOM = "MOM",
  PC = "PC",
  TM = "TM",
  TRAINER = "TRAINER",
  ROCKET = "ROCKET",
}
local LINE_CONTROLS = {
  CR = true,
  LF = true,
  LINE = true,
  NEXT = true,
}
local CONTINUATION_CONTROLS = {
  _CONT = true,
  CONT = true,
  SCROLL = true,
}

local function fail(message, level)
  error("Crystal text data: " .. message, level or 3)
end

local function append(tokens, kind, value)
  if kind == "text" and value == "" then return end
  local previous = tokens[#tokens]
  if kind == "text" and previous and previous.kind == "text" then
    previous.value = previous.value .. value
  else
    local token = { kind = kind }
    if value ~= nil then token.value = value end
    tokens[#tokens + 1] = token
  end
end

local function appendControl(tokens, unit)
  local name = unit.name
  if LINE_CONTROLS[name] then
    append(tokens, "line")
  elseif CONTINUATION_CONTROLS[name] then
    append(tokens, "continuation")
  elseif name == "PARA" then
    append(tokens, "paragraph")
  elseif name == "PLAYER" or name == "PLAY_G" then
    append(tokens, "substitution", "player")
  elseif CONTROL_TEXT[name] then
    append(tokens, "text", CONTROL_TEXT[name])
  elseif name == "WBR" then
    append(tokens, "text", " ")
  else
    append(tokens, "control", name)
  end
end

local function decodeLiteral(rom, cursor, tokens, consumed)
  while consumed.value < MAX_ENTRY_BYTES do
    local byte = rom:readByte(cursor)
    cursor = cursor + 1
    consumed.value = consumed.value + 1
    local terminal = TEXT_TERMINALS[byte]
    if terminal then return cursor, terminal end
    if byte == TX_END then return cursor, nil end

    local unit = Charmap.lookup(byte)
    if not unit then
      fail(("unknown charmap byte 0x%02X at ROM offset 0x%X")
        :format(byte, cursor - 1), 2)
    elseif unit.kind == "glyph" then
      append(tokens, "text", unit.text)
    elseif unit.kind == "control" then
      appendControl(tokens, unit)
    else
      fail(("unexpected %s in text at ROM offset 0x%X")
        :format(unit.kind, cursor - 1), 2)
    end
  end
  fail("entry exceeded the 4096-byte safety limit", 2)
end

local function decodeEntry(rom, offset, definition)
  local cursor = offset
  local tokens = {}
  local consumed = { value = 0 }
  local ramIndex = 0

  while consumed.value < MAX_ENTRY_BYTES do
    local command = rom:readByte(cursor)
    cursor = cursor + 1
    consumed.value = consumed.value + 1
    if command == TX_START then
      local terminal
      cursor, terminal = decodeLiteral(rom, cursor, tokens, consumed)
      if terminal then
        return {
          tokens = tokens,
          terminal = terminal,
          byteLength = consumed.value,
        }
      end
    elseif command == TX_RAM then
      rom:assertRange(cursor, 2)
      cursor = cursor + 2
      consumed.value = consumed.value + 2
      ramIndex = ramIndex + 1
      local key = definition.ramKeys and definition.ramKeys[ramIndex]
      append(tokens, "substitution", key or ("ram_" .. ramIndex))
    elseif command == TX_PROMPT_BUTTON then
      -- This command adds an input wait but no glyphs. The native
      -- presentation controller already owns the wait for each request.
    elseif command == TX_END then
      return {
        tokens = tokens,
        terminal = "end",
        byteLength = consumed.value,
      }
    else
      fail(("unsupported command 0x%02X at ROM offset 0x%X")
        :format(command, cursor - 1), 2)
    end
  end
  fail("entry exceeded the 4096-byte safety limit", 2)
end

function CrystalTextData.extract(rom, profile)
  if type(rom) ~= "table"
      or type(rom.readByte) ~= "function"
      or type(rom.assertRange) ~= "function" then
    fail("a ROM reader is required", 2)
  end
  if type(profile) ~= "table"
      or type(profile.id) ~= "string"
      or type(profile.text) ~= "table"
      or profile.text.schema ~= 1
      or type(profile.text.entries) ~= "table" then
    fail("profile text schema 1 is required", 2)
  end

  local entries = {}
  local count = 0
  for id, definition in pairs(profile.text.entries) do
    local symbol = profile.symbols
      and profile.symbols[definition.symbol]
    if type(symbol) ~= "table" or type(symbol.offset) ~= "number" then
      fail(("profile %s is missing symbol %s for %s")
        :format(profile.id, tostring(definition.symbol), id), 2)
    end
    entries[id] = decodeEntry(rom, symbol.offset, definition)
    count = count + 1
  end

  return {
    schema = 1,
    profileId = profile.id,
    count = count,
    aliases = profile.text.aliases or {},
    entries = entries,
  }
end

CrystalTextData.decodeEntry = decodeEntry

return CrystalTextData
