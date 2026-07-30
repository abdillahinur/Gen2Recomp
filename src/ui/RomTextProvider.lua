local RomTextProvider = {}
RomTextProvider.__index = RomTextProvider

local MENU_TEXT = {
  ["common.text.yes"] = "YES",
  ["common.text.no"] = "NO",
  ["crystal.text.player_gender.boy"] = "BOY",
  ["crystal.text.player_gender.girl"] = "GIRL",
}

local function semanticValue(value)
  local text = tostring(value)
  local tail = text:match("([^.]+)$") or text
  return tail:gsub("_", " "):upper()
end

local function copy(values)
  local result = {}
  for key, value in pairs(values or {}) do result[key] = value end
  return result
end

local function pushPage(pages, lines)
  if #lines == 0 then return end
  pages[#pages + 1] = table.concat(lines, "\n")
end

local function renderPages(entry, values)
  local pages = {}
  local lines = { "" }
  local function newLine(forcePage)
    if forcePage or #lines >= 2 then
      pushPage(pages, lines)
      lines = { "" }
    else
      lines[#lines + 1] = ""
    end
  end

  for _, token in ipairs(entry.tokens) do
    if token.kind == "text" then
      lines[#lines] = lines[#lines] .. token.value
    elseif token.kind == "substitution" then
      lines[#lines] = lines[#lines]
        .. semanticValue(values[token.value] or token.value)
    elseif token.kind == "line" then
      newLine(false)
    elseif token.kind == "continuation" then
      newLine(#lines >= 2)
    elseif token.kind == "paragraph" then
      newLine(true)
    elseif token.kind == "control" then
      lines[#lines] = lines[#lines] .. "<" .. token.value .. ">"
    end
  end
  pushPage(pages, lines)
  if #pages == 0 then pages[1] = "" end
  return pages
end

function RomTextProvider.new(catalog, options)
  if type(catalog) ~= "table"
      or catalog.schema ~= 1
      or type(catalog.entries) ~= "table" then
    error("ROM text provider requires decoded text schema 1", 2)
  end
  options = options or {}
  return setmetatable({
    catalog = catalog,
    values = options.values,
  }, RomTextProvider)
end

function RomTextProvider:_values(substitutions)
  local values = {}
  if type(self.values) == "function" then
    values = copy(self.values() or {})
  elseif type(self.values) == "table" then
    values = copy(self.values)
  end
  for key, value in pairs(substitutions or {}) do values[key] = value end
  return values
end

function RomTextProvider:resolvePages(id, substitutions)
  local target = self.catalog.aliases and self.catalog.aliases[id] or id
  local entry = self.catalog.entries[target]
  if not entry then
    error("ROM text is not extracted for " .. tostring(id), 2)
  end
  return renderPages(entry, self:_values(substitutions))
end

function RomTextProvider:resolve(id, substitutions)
  return table.concat(self:resolvePages(id, substitutions), "\n\n")
end

function RomTextProvider:choicePromptPages(id)
  if not (self.catalog.aliases and self.catalog.aliases[id]) then return nil end
  return self:resolvePages(id)
end

function RomTextProvider:choiceTitle(id)
  return "YES OR NO?"
end

function RomTextProvider:option(option)
  if MENU_TEXT[option.textId] then return MENU_TEXT[option.textId] end
  local entry = self.catalog.entries[option.textId]
  if entry then
    return self:resolve(option.textId)
  end
  error("ROM menu text is not extracted for "
    .. tostring(option.textId), 2)
end

function RomTextProvider.forState(catalog, state)
  return RomTextProvider.new(catalog, {
    values = function()
      return {
        player = state
          and state:getVariable("player.name", "PLAYER")
          or "PLAYER",
      }
    end,
  })
end

return RomTextProvider
