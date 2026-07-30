local SemanticTextProvider = {}
SemanticTextProvider.__index = SemanticTextProvider

local OVERRIDES = {
  ["common.text.yes"] = "YES",
  ["common.text.no"] = "NO",
  ["crystal.text.player_gender.boy"] = "BOY",
  ["crystal.text.player_gender.girl"] = "GIRL",
}

local function humanize(id)
  local value = OVERRIDES[id]
  if value then return value end
  local tail = id:match("([^.]+%.[^.]+)$") or id
  return tail:gsub("%.", " · "):gsub("_", " "):upper()
end

function SemanticTextProvider.new()
  return setmetatable({}, SemanticTextProvider)
end

function SemanticTextProvider:resolve(id, substitutions)
  local text = humanize(id)
  local values = {}
  for key, value in pairs(substitutions or {}) do
    values[#values + 1] =
      tostring(key):upper() .. ": " .. humanize(tostring(value))
  end
  table.sort(values)
  if #values > 0 then
    text = text .. "\n" .. table.concat(values, "  ")
  end
  return text
end

function SemanticTextProvider:option(option)
  return humanize(option.textId)
end

return SemanticTextProvider
