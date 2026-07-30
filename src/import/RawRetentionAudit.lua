local RawRetentionAudit = {}

local DEFAULT_WINDOW_BYTES = 4096
local DEFAULT_STRIDE_BYTES = 1024

local function positiveInteger(value, name)
  if type(value) ~= "number" or value < 1 or value % 1 ~= 0 then
    error(name .. " must be a positive integer", 3)
  end
  return value
end

local function candidateStarts(length, window, stride)
  local starts = {}
  local seen = {}
  local last = length - window + 1
  for start = 1, last, stride do
    starts[#starts + 1] = start
    seen[start] = true
  end
  if not seen[last] then
    starts[#starts + 1] = last
  end
  return starts
end

local function inspectString(source, value, path, audit)
  audit.stringsVisited = audit.stringsVisited + 1
  if #value < audit.windowBytes then
    return
  end
  audit.largeStringsInspected = audit.largeStringsInspected + 1

  if #value <= #source and source:find(value, 1, true) then
    error(("decoded data retains a %d-byte raw ROM range at %s")
      :format(#value, path), 3)
  end

  for _, start in ipairs(candidateStarts(
    #value,
    audit.windowBytes,
    audit.strideBytes
  )) do
    local candidate =
      value:sub(start, start + audit.windowBytes - 1)
    audit.candidateWindows = audit.candidateWindows + 1
    if source:find(candidate, 1, true) then
      error(("decoded data retains a raw ROM window at %s")
        :format(path), 3)
    end
  end
end

function RawRetentionAudit.inspect(rom, value, options)
  options = options or {}
  if type(rom) ~= "table"
      or type(rom.size) ~= "function"
      or type(rom.readString) ~= "function" then
    error("raw-retention audit requires a ROM reader", 2)
  end

  local window = positiveInteger(
    options.windowBytes or DEFAULT_WINDOW_BYTES,
    "raw-retention window size"
  )
  local stride = positiveInteger(
    options.strideBytes or DEFAULT_STRIDE_BYTES,
    "raw-retention stride"
  )
  if stride > window then
    error("raw-retention stride cannot exceed its window size", 2)
  end

  local source = rom:readString(0, rom:size())
  local audit = {
    status = "passed",
    windowBytes = window,
    strideBytes = stride,
    stringsVisited = 0,
    largeStringsInspected = 0,
    candidateWindows = 0,
  }
  local stack = {
    { value = value, path = "$" },
  }
  local seen = {}

  while #stack > 0 do
    local entry = stack[#stack]
    stack[#stack] = nil
    local kind = type(entry.value)
    if kind == "string" then
      inspectString(source, entry.value, entry.path, audit)
    elseif kind == "table" and not seen[entry.value] then
      seen[entry.value] = true
      for key, child in pairs(entry.value) do
        local childPath = entry.path .. "[" .. tostring(key) .. "]"
        if type(key) == "string" then
          inspectString(source, key, childPath .. "<key>", audit)
        end
        if type(child) == "string" or type(child) == "table" then
          stack[#stack + 1] = {
            value = child,
            path = childPath,
          }
        end
      end
    end
  end

  source = nil
  return audit
end

RawRetentionAudit.DEFAULT_WINDOW_BYTES = DEFAULT_WINDOW_BYTES
RawRetentionAudit.DEFAULT_STRIDE_BYTES = DEFAULT_STRIDE_BYTES

return RawRetentionAudit
