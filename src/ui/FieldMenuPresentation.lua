local Dvs = require("src.pokemon.Dvs")
local StatCalculator = require("src.pokemon.StatCalculator")

local FieldMenuPresentation = {}
FieldMenuPresentation.__index = FieldMenuPresentation

local ROOT = {
  { id = "pokedex", label = "POKéDEX" },
  { id = "party", label = "POKéMON" },
  { id = "pack", label = "PACK" },
  { id = "close", label = "CLOSE" },
}

local function pressed(input, action)
  return input and input:wasPressed(action)
end

local function wrap(value, maximum)
  if maximum < 1 then return 1 end
  if value < 1 then return maximum end
  if value > maximum then return 1 end
  return value
end

local function slug(id)
  return tostring(id):match("([^.]+)$")
end

local function label(id)
  local value = slug(id):gsub("_", " "):upper()
  return value
end

local function sortedItems(items)
  local ids = {}
  for id, count in pairs(items or {}) do
    if count > 0 then ids[#ids + 1] = id end
  end
  table.sort(ids)
  local result = {}
  for _, id in ipairs(ids) do
    result[#result + 1] = {
      id = id,
      name = label(id),
      quantity = items[id],
    }
  end
  return result
end

function FieldMenuPresentation.new(gameSession, battleData, options)
  if type(gameSession) ~= "table"
      or type(gameSession.party) ~= "table"
      or type(gameSession.inventory) ~= "table"
      or type(gameSession.pokedex) ~= "table" then
    error("field menu requires a game session", 2)
  end
  if type(battleData) ~= "table"
      or type(battleData.species) ~= "table" then
    error("field menu requires Crystal species data", 2)
  end
  options = options or {}
  local bySlug = {}
  for _, species in ipairs(battleData.species) do
    bySlug[slug(species.id)] = species
  end
  return setmetatable({
    gameSession = gameSession,
    species = battleData.species,
    bySlug = bySlug,
    onClose = options.onClose,
    mode = "root",
    rootIndex = 1,
    listIndex = 1,
  }, FieldMenuPresentation)
end

function FieldMenuPresentation:_hasPokedex()
  return self.gameSession.state:hasFlag("crystal.feature.pokedex")
end

function FieldMenuPresentation:_count(mode)
  if mode == "pack" then
    return #sortedItems(self.gameSession.inventory.items)
  elseif mode == "party" then
    return #self.gameSession.party.members
  elseif mode == "pokedex" then
    return #self.species
  end
  return #ROOT
end

function FieldMenuPresentation:update(input)
  if self.mode == "root" then
    if pressed(input, "up") then
      self.rootIndex = wrap(self.rootIndex - 1, #ROOT)
    elseif pressed(input, "down") then
      self.rootIndex = wrap(self.rootIndex + 1, #ROOT)
    elseif pressed(input, "cancel") or pressed(input, "start") then
      if self.onClose then self.onClose() end
    elseif pressed(input, "confirm") then
      local selected = ROOT[self.rootIndex].id
      if selected == "close" then
        if self.onClose then self.onClose() end
      elseif selected ~= "pokedex" or self:_hasPokedex() then
        self.mode = selected
        self.listIndex = 1
      end
    end
    return true
  end

  local count = self:_count(self.mode)
  if pressed(input, "start") then
    if self.onClose then self.onClose() end
  elseif pressed(input, "cancel") then
    local previous = self.mode
    self.mode = "root"
    self.rootIndex = previous == "party" and 2
      or previous == "pack" and 3 or 1
  elseif pressed(input, "up") and count > 0 then
    self.listIndex = wrap(self.listIndex - 1, count)
  elseif pressed(input, "down") and count > 0 then
    self.listIndex = wrap(self.listIndex + 1, count)
  elseif self.mode == "pokedex" and pressed(input, "left") then
    self.listIndex = wrap(self.listIndex - 10, count)
  elseif self.mode == "pokedex" and pressed(input, "right") then
    self.listIndex = wrap(self.listIndex + 10, count)
  end
  return true
end

function FieldMenuPresentation:_partyModel()
  local values = {}
  for index, member in ipairs(self.gameSession.party.members) do
    local species = self.bySlug[slug(member.speciesId)]
    local dvs = Dvs.normalize(member.dvs)
    local stats = species
      and StatCalculator.calculate(species, member.level, dvs)
      or { hp = member.currentHP or 0 }
    values[index] = {
      name = member.nickname
        or species and species.name
        or label(member.speciesId),
      level = member.level,
      hp = member.currentHP or stats.hp,
      maxHP = stats.hp,
      heldItem = member.heldItemId and label(member.heldItemId) or nil,
    }
  end
  return {
    kind = "party",
    title = "POKéMON",
    options = values,
    selected = self.listIndex,
    empty = #values == 0,
  }
end

function FieldMenuPresentation:_pokedexModel()
  local seen = self.gameSession.pokedex.seen
  local caught = self.gameSession.pokedex.caught
  local options = {}
  local seenCount, caughtCount = 0, 0
  for index, species in ipairs(self.species) do
    local key = "crystal.species." .. slug(species.id)
    local wasSeen = seen[key] == true
    local wasCaught = caught[key] == true
    if wasSeen then seenCount = seenCount + 1 end
    if wasCaught then caughtCount = caughtCount + 1 end
    options[index] = {
      number = index,
      name = wasSeen and species.name or "----------",
      seen = wasSeen,
      caught = wasCaught,
    }
  end
  return {
    kind = "pokedex",
    title = "POKéDEX",
    options = options,
    selected = self.listIndex,
    seen = seenCount,
    caught = caughtCount,
  }
end

function FieldMenuPresentation:model()
  if self.mode == "root" then
    local options = {}
    for index, option in ipairs(ROOT) do
      options[index] = {
        id = option.id,
        name = option.label,
        disabled = option.id == "pokedex" and not self:_hasPokedex(),
      }
    end
    return {
      kind = "root",
      title = "MENU",
      options = options,
      selected = self.rootIndex,
    }
  elseif self.mode == "pack" then
    local options = sortedItems(self.gameSession.inventory.items)
    return {
      kind = "pack",
      title = "PACK",
      options = options,
      selected = self.listIndex,
      empty = #options == 0,
    }
  elseif self.mode == "party" then
    return self:_partyModel()
  end
  return self:_pokedexModel()
end

return FieldMenuPresentation
