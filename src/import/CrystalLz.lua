local CrystalLz = {}

local DEFAULT_MAX_OUTPUT_SIZE = 4 * 1024 * 1024

local function flipByte(value)
  local flipped = 0
  for bit = 0, 7 do
    if math.floor(value / 2 ^ bit) % 2 == 1 then
      flipped = flipped + 2 ^ (7 - bit)
    end
  end
  return flipped
end

local function readByte(state, context)
  local value = state.source:byte(state.position)
  if value == nil then
    error("truncated Crystal LZ " .. context, 3)
  end
  state.position = state.position + 1
  return value
end

local function appendByte(output, value)
  output[#output + 1] = value
end

local function decodeLookback(state, output, command, length)
  local first = readByte(state, "lookback offset")
  local base
  if first >= 0x80 then
    base = #output - (first % 0x80)
  else
    base = first * 0x100 + readByte(state, "absolute offset") + 1
  end

  for index = 0, length - 1 do
    local sourceIndex
    if command == 6 then
      sourceIndex = base - index
    else
      sourceIndex = base + index
    end
    local value = output[sourceIndex]
    if value == nil then
      error("Crystal LZ lookback points outside prior output", 3)
    end
    if command == 5 then
      value = flipByte(value)
    end
    appendByte(output, value)
  end
end

local function outputString(bytes)
  local characters = {}
  for index, value in ipairs(bytes) do
    characters[index] = string.char(value)
  end
  return table.concat(characters)
end

function CrystalLz.decompress(source, options)
  if type(source) ~= "string" then
    error("Crystal LZ source must be a binary string", 2)
  end
  options = options or {}
  local maximum = options.maxOutputSize or DEFAULT_MAX_OUTPUT_SIZE
  if type(maximum) ~= "number" or maximum < 1
      or maximum % 1 ~= 0 then
    error("Crystal LZ maximum output size must be a positive integer", 2)
  end

  local state = {
    source = source,
    position = 1,
  }
  local output = {}
  local commandCount = 0

  while true do
    local header = readByte(state, "command")
    if header == 0xff then
      return outputString(output), {
        consumedBytes = state.position - 1,
        commandCount = commandCount,
      }
    end

    local command = math.floor(header / 0x20)
    local length = header % 0x20
    if command == 7 then
      command = math.floor(length / 4)
      length = (length % 4) * 0x100
        + readByte(state, "long-command length")
    end
    length = length + 1
    if command > 6 then
      error(("invalid Crystal LZ command %d"):format(command), 2)
    end
    if #output + length > maximum then
      error("Crystal LZ output exceeds configured limit", 2)
    end
    commandCount = commandCount + 1

    if command == 0 then
      for _ = 1, length do
        appendByte(output, readByte(state, "literal data"))
      end
    elseif command == 1 then
      local value = readByte(state, "iterate value")
      for _ = 1, length do
        appendByte(output, value)
      end
    elseif command == 2 then
      local first = readByte(state, "alternate value")
      local second = readByte(state, "alternate value")
      for index = 0, length - 1 do
        appendByte(output, index % 2 == 0 and first or second)
      end
    elseif command == 3 then
      for _ = 1, length do
        appendByte(output, 0)
      end
    else
      decodeLookback(state, output, command, length)
    end
  end
end

CrystalLz.DEFAULT_MAX_OUTPUT_SIZE = DEFAULT_MAX_OUTPUT_SIZE

return CrystalLz
