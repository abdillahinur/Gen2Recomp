local BattleSide = {}
BattleSide.__index = BattleSide

function BattleSide.new(id, party)
  if type(id) ~= "string" or id == "" then
    error("battle side: id is required", 2)
  end
  if type(party) ~= "table" or #party == 0 or #party > 6 then
    error("battle side: party must contain one to six Pokemon", 2)
  end
  local copied = {}
  for index, pokemon in ipairs(party) do
    if type(pokemon) ~= "table"
        or type(pokemon.isFainted) ~= "function" then
      error("battle side: party contains an invalid Pokemon", 2)
    end
    copied[index] = pokemon
  end
  local activeIndex
  for index, pokemon in ipairs(copied) do
    if not pokemon:isFainted() then
      activeIndex = index
      break
    end
  end
  if not activeIndex then
    error("battle side: party has no usable Pokemon", 2)
  end
  return setmetatable({
    id = id,
    party = copied,
    activeIndex = activeIndex,
  }, BattleSide)
end

function BattleSide:active()
  return self.party[self.activeIndex]
end

function BattleSide:hasUsablePokemon()
  for _, pokemon in ipairs(self.party) do
    if not pokemon:isFainted() then return true end
  end
  return false
end

function BattleSide:firstAvailable(excludedIndex)
  for index, pokemon in ipairs(self.party) do
    if index ~= excludedIndex and not pokemon:isFainted() then
      return index
    end
  end
end

return BattleSide
