local Json = {}

local ARRAY_METATABLE = {}
local NULL = {}

local ESCAPES = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encodeString(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
    return ESCAPES[character]
      or ("\\u%04x"):format(character:byte())
  end) .. '"'
end

local function tableShape(value)
  if getmetatable(value) == ARRAY_METATABLE then
    return "array", #value
  end

  local count = 0
  local maximum = 0
  local onlyPositiveIntegers = true
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      onlyPositiveIntegers = false
    elseif key > maximum then
      maximum = key
    end
  end

  if count > 0 and onlyPositiveIntegers and maximum == count then
    return "array", count
  end
  return "object"
end

local function encodeValue(value, ancestors)
  local valueType = type(value)
  if value == NULL then
    return "null"
  elseif valueType == "nil" then
    error("JSON cannot encode nil", 3)
  elseif valueType == "boolean" then
    return value and "true" or "false"
  elseif valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("JSON cannot encode a non-finite number", 3)
    end
    return ("%.17g"):format(value)
  elseif valueType == "string" then
    return encodeString(value)
  elseif valueType ~= "table" then
    error("JSON cannot encode " .. valueType, 3)
  end

  if ancestors[value] then
    error("JSON cannot encode a cyclic table", 3)
  end
  ancestors[value] = true

  local shape, length = tableShape(value)
  local parts = {}
  if shape == "array" then
    for index = 1, length do
      if value[index] == nil then
        ancestors[value] = nil
        error("JSON arrays cannot contain holes", 3)
      end
      parts[index] = encodeValue(value[index], ancestors)
    end
    ancestors[value] = nil
    return "[" .. table.concat(parts, ",") .. "]"
  end

  local keys = {}
  for key in pairs(value) do
    if type(key) ~= "string" then
      ancestors[value] = nil
      error("JSON object keys must be strings", 3)
    end
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for index, key in ipairs(keys) do
    parts[index] = encodeString(key)
      .. ":"
      .. encodeValue(value[key], ancestors)
  end
  ancestors[value] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

local function decodeError(parser, message)
  error(("JSON decode error at byte %d: %s")
    :format(parser.position, message), 0)
end

local function skipWhitespace(parser)
  local _, finish = parser.source:find("^[ \t\r\n]*", parser.position)
  parser.position = (finish or parser.position - 1) + 1
end

local function appendUtf8(parts, codepoint)
  if codepoint <= 0x7f then
    parts[#parts + 1] = string.char(codepoint)
  elseif codepoint <= 0x7ff then
    parts[#parts + 1] = string.char(
      0xc0 + math.floor(codepoint / 0x40),
      0x80 + codepoint % 0x40
    )
  elseif codepoint <= 0xffff then
    parts[#parts + 1] = string.char(
      0xe0 + math.floor(codepoint / 0x1000),
      0x80 + math.floor(codepoint / 0x40) % 0x40,
      0x80 + codepoint % 0x40
    )
  else
    parts[#parts + 1] = string.char(
      0xf0 + math.floor(codepoint / 0x40000),
      0x80 + math.floor(codepoint / 0x1000) % 0x40,
      0x80 + math.floor(codepoint / 0x40) % 0x40,
      0x80 + codepoint % 0x40
    )
  end
end

local function readHexCodepoint(parser)
  local value = parser.source:sub(parser.position, parser.position + 3)
  if #value ~= 4 or value:match("^[0-9a-fA-F]+$") == nil then
    decodeError(parser, "invalid Unicode escape")
  end
  parser.position = parser.position + 4
  return tonumber(value, 16)
end

local function parseString(parser)
  parser.position = parser.position + 1
  local parts = {}
  local chunkStart = parser.position

  while parser.position <= parser.length do
    local byte = parser.source:byte(parser.position)
    if byte == 0x22 then
      parts[#parts + 1] =
        parser.source:sub(chunkStart, parser.position - 1)
      parser.position = parser.position + 1
      return table.concat(parts)
    elseif byte == 0x5c then
      parts[#parts + 1] =
        parser.source:sub(chunkStart, parser.position - 1)
      parser.position = parser.position + 1
      local escaped = parser.source:sub(parser.position, parser.position)
      local simple = {
        ['"'] = '"',
        ["\\"] = "\\",
        ["/"] = "/",
        b = "\b",
        f = "\f",
        n = "\n",
        r = "\r",
        t = "\t",
      }
      if simple[escaped] then
        parts[#parts + 1] = simple[escaped]
        parser.position = parser.position + 1
      elseif escaped == "u" then
        parser.position = parser.position + 1
        local codepoint = readHexCodepoint(parser)
        if codepoint >= 0xd800 and codepoint <= 0xdbff then
          if parser.source:sub(parser.position, parser.position + 1)
              ~= "\\u" then
            decodeError(parser, "high surrogate is missing its pair")
          end
          parser.position = parser.position + 2
          local low = readHexCodepoint(parser)
          if low < 0xdc00 or low > 0xdfff then
            decodeError(parser, "invalid low surrogate")
          end
          codepoint = 0x10000
            + (codepoint - 0xd800) * 0x400
            + low - 0xdc00
        elseif codepoint >= 0xdc00 and codepoint <= 0xdfff then
          decodeError(parser, "unexpected low surrogate")
        end
        appendUtf8(parts, codepoint)
      else
        decodeError(parser, "invalid string escape")
      end
      chunkStart = parser.position
    elseif byte < 0x20 then
      decodeError(parser, "unescaped control character in string")
    else
      parser.position = parser.position + 1
    end
  end

  decodeError(parser, "unterminated string")
end

local function parseNumber(parser)
  local start = parser.position
  if parser.source:sub(parser.position, parser.position) == "-" then
    parser.position = parser.position + 1
  end

  local first = parser.source:sub(parser.position, parser.position)
  if first == "0" then
    parser.position = parser.position + 1
    if parser.source:sub(parser.position, parser.position):match("%d") then
      decodeError(parser, "number has a leading zero")
    end
  elseif first:match("[1-9]") then
    repeat
      parser.position = parser.position + 1
    until not parser.source:sub(parser.position, parser.position):match("%d")
  else
    decodeError(parser, "invalid number")
  end

  if parser.source:sub(parser.position, parser.position) == "." then
    parser.position = parser.position + 1
    if not parser.source:sub(parser.position, parser.position):match("%d") then
      decodeError(parser, "fraction requires a digit")
    end
    repeat
      parser.position = parser.position + 1
    until not parser.source:sub(parser.position, parser.position):match("%d")
  end

  local exponent = parser.source:sub(parser.position, parser.position)
  if exponent == "e" or exponent == "E" then
    parser.position = parser.position + 1
    local sign = parser.source:sub(parser.position, parser.position)
    if sign == "+" or sign == "-" then
      parser.position = parser.position + 1
    end
    if not parser.source:sub(parser.position, parser.position):match("%d") then
      decodeError(parser, "exponent requires a digit")
    end
    repeat
      parser.position = parser.position + 1
    until not parser.source:sub(parser.position, parser.position):match("%d")
  end

  local value = tonumber(parser.source:sub(start, parser.position - 1))
  if value == nil or value == math.huge or value == -math.huge then
    decodeError(parser, "number is outside the supported range")
  end
  return value
end

local parseValue

local function parseArray(parser, depth)
  parser.position = parser.position + 1
  skipWhitespace(parser)
  local result = Json.array({})
  if parser.source:sub(parser.position, parser.position) == "]" then
    parser.position = parser.position + 1
    return result
  end

  while true do
    result[#result + 1] = parseValue(parser, depth + 1)
    skipWhitespace(parser)
    local character = parser.source:sub(parser.position, parser.position)
    if character == "]" then
      parser.position = parser.position + 1
      return result
    elseif character ~= "," then
      decodeError(parser, "expected ',' or ']'")
    end
    parser.position = parser.position + 1
    skipWhitespace(parser)
  end
end

local function parseObject(parser, depth)
  parser.position = parser.position + 1
  skipWhitespace(parser)
  local result = {}
  if parser.source:sub(parser.position, parser.position) == "}" then
    parser.position = parser.position + 1
    return result
  end

  while true do
    if parser.source:sub(parser.position, parser.position) ~= '"' then
      decodeError(parser, "object key must be a string")
    end
    local key = parseString(parser)
    if result[key] ~= nil then
      decodeError(parser, "duplicate object key")
    end
    skipWhitespace(parser)
    if parser.source:sub(parser.position, parser.position) ~= ":" then
      decodeError(parser, "expected ':' after object key")
    end
    parser.position = parser.position + 1
    skipWhitespace(parser)
    result[key] = parseValue(parser, depth + 1)
    skipWhitespace(parser)

    local character = parser.source:sub(parser.position, parser.position)
    if character == "}" then
      parser.position = parser.position + 1
      return result
    elseif character ~= "," then
      decodeError(parser, "expected ',' or '}'")
    end
    parser.position = parser.position + 1
    skipWhitespace(parser)
  end
end

parseValue = function(parser, depth)
  if depth > 128 then
    decodeError(parser, "maximum nesting depth exceeded")
  end
  skipWhitespace(parser)
  local character = parser.source:sub(parser.position, parser.position)

  if character == '"' then
    return parseString(parser)
  elseif character == "{" then
    return parseObject(parser, depth)
  elseif character == "[" then
    return parseArray(parser, depth)
  elseif character == "-" or character:match("%d") then
    return parseNumber(parser)
  elseif parser.source:sub(parser.position, parser.position + 3) == "true" then
    parser.position = parser.position + 4
    return true
  elseif parser.source:sub(parser.position, parser.position + 4) == "false" then
    parser.position = parser.position + 5
    return false
  elseif parser.source:sub(parser.position, parser.position + 3) == "null" then
    parser.position = parser.position + 4
    return NULL
  end
  decodeError(parser, "unexpected token")
end

function Json.array(values)
  if type(values) ~= "table" then
    error("JSON array value must be a table", 2)
  end
  return setmetatable(values, ARRAY_METATABLE)
end

function Json.isArray(value)
  return type(value) == "table" and getmetatable(value) == ARRAY_METATABLE
end

function Json.encode(value)
  return encodeValue(value, {})
end

function Json.decode(source)
  if type(source) ~= "string" then
    error("JSON source must be a string", 2)
  end
  local parser = {
    source = source,
    length = #source,
    position = 1,
  }
  local value = parseValue(parser, 0)
  skipWhitespace(parser)
  if parser.position <= parser.length then
    decodeError(parser, "trailing content")
  end
  return value
end

Json.null = NULL

return Json
