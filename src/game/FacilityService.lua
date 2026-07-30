local Dvs = require("src.pokemon.Dvs")
local StatCalculator = require("src.pokemon.StatCalculator")

local FacilityService = {}
FacilityService.__index = FacilityService

local PRICES = {
  ["crystal.item.poke_ball"] = 200,
  ["crystal.item.potion"] = 300,
  ["crystal.item.antidote"] = 100,
  ["crystal.item.parlyz_heal"] = 200,
  ["crystal.item.awakening"] = 250,
  ["crystal.item.escape_rope"] = 550,
  ["crystal.item.x_attack"] = 500,
  ["crystal.item.x_defend"] = 550,
  ["crystal.item.x_speed"] = 350,
}

local CATALOGS = {
  cherrygrove = {
    "crystal.item.potion",
    "crystal.item.antidote",
    "crystal.item.parlyz_heal",
    "crystal.item.awakening",
  },
  cherrygrove_dex = {
    "crystal.item.poke_ball",
    "crystal.item.potion",
    "crystal.item.antidote",
    "crystal.item.parlyz_heal",
    "crystal.item.awakening",
  },
  violet = {
    "crystal.item.poke_ball",
    "crystal.item.potion",
    "crystal.item.escape_rope",
    "crystal.item.antidote",
    "crystal.item.parlyz_heal",
    "crystal.item.awakening",
    "crystal.item.x_attack",
    "crystal.item.x_defend",
    "crystal.item.x_speed",
  },
}

local function slug(id)
  return tostring(id):match("([^.]+)$")
end

local function indexSpecies(data)
  local result = {}
  for _, species in ipairs(data.species or {}) do
    result[slug(species.id)] = species
  end
  return result
end

function FacilityService.new(gameSession, battleData)
  return setmetatable({
    game = gameSession,
    species = indexSpecies(battleData),
  }, FacilityService)
end

function FacilityService:maxHP(member)
  local species = self.species[slug(member.speciesId)]
  if not species then return member.currentHP or 1 end
  return StatCalculator.calculate(
    species,
    member.level,
    Dvs.normalize(member.dvs)
  ).hp
end

function FacilityService:healParty()
  for _, member in ipairs(self.game.party.members) do
    member.currentHP = self:maxHP(member)
  end
  return #self.game.party.members
end

function FacilityService:catalog(id)
  local source = CATALOGS[id] or {}
  local result = {}
  for index, itemId in ipairs(source) do
    result[index] = { id = itemId, price = PRICES[itemId] }
  end
  return result
end

function FacilityService:buy(itemId, count)
  count = count or 1
  local price = PRICES[itemId]
  if not price then return nil, "not_sold_here" end
  local total = price * count
  if self.game.money < total then return nil, "not_enough_money" end
  self.game.money = self.game.money - total
  self.game.inventory:give(itemId, count)
  return total
end

function FacilityService:sell(itemId, count)
  count = count or 1
  local price = PRICES[itemId]
  if not price then return nil, "cannot_sell" end
  local _, reason = self.game.inventory:remove(itemId, count)
  if reason then return nil, reason end
  local proceeds = math.floor(price / 2) * count
  self.game.money = math.min(999999, self.game.money + proceeds)
  return proceeds
end

function FacilityService:usePotion(partyIndex)
  local member = self.game.party.members[partyIndex]
  if not member then return nil, "invalid_party_index" end
  if self.game.inventory:count("crystal.item.potion") < 1 then
    return nil, "no_potion"
  end
  local maximum = self:maxHP(member)
  local current = member.currentHP or maximum
  if current >= maximum then return nil, "full_hp" end
  local healed = math.min(20, maximum - current)
  member.currentHP = current + healed
  self.game.inventory:remove("crystal.item.potion", 1)
  return healed
end

FacilityService.PRICES = PRICES

return FacilityService
