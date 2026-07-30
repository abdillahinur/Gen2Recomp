local BattleSession = require("src.battle.BattleSession")
local PokemonInstance = require("src.pokemon.PokemonInstance")

local SCENARIOS = require("manifests.crystal_battle_scenarios")

local BattleRequestFactory = {}
BattleRequestFactory.__index = BattleRequestFactory

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end

local function slug(id)
  return tostring(id):match("([^.]+)$")
end

local function stableSpeciesId(id)
  return "crystal.species." .. slug(id)
end

function BattleRequestFactory.new(registry, data, gameSession, options)
  if type(registry) ~= "table" or type(registry.get) ~= "function" then
    error("battle request factory requires a data registry", 2)
  end
  if type(data) ~= "table"
      or type(data.speciesIds) ~= "table"
      or type(data.moveIds) ~= "table" then
    error("battle request factory requires Crystal battle data", 2)
  end
  if type(gameSession) ~= "table"
      or type(gameSession.party) ~= "table" then
    error("battle request factory requires a game session", 2)
  end
  options = options or {}
  local speciesNumbers = {}
  for number, id in ipairs(data.speciesIds) do
    speciesNumbers[slug(id)] = number
  end
  return setmetatable({
    registry = registry,
    data = data,
    gameSession = gameSession,
    scenarios = options.scenarios or SCENARIOS,
    speciesNumbers = speciesNumbers,
  }, BattleRequestFactory)
end

function BattleRequestFactory:_number(speciesId)
  local number = self.speciesNumbers[slug(speciesId)]
  if not number then
    error("battle request factory: unknown species " .. speciesId, 2)
  end
  return number
end

function BattleRequestFactory:_moveSlots(numbers)
  local result = {}
  for index, number in ipairs(numbers) do
    local id = self.data.moveIds[number]
    local move = id and self.registry:get("moves", id)
    if not move then
      error("battle request factory: unknown move " .. tostring(number), 2)
    end
    result[index] = {
      id = id,
      pp = move.pp,
      maxPP = move.pp,
    }
  end
  return result
end

function BattleRequestFactory:_pokemon(source)
  local number = source.speciesNumber
    or self:_number(source.speciesId)
  local speciesId = self.data.speciesIds[number]
  local species = speciesId
    and self.registry:get("species", speciesId)
  if not species then
    error("battle request factory: unavailable species number "
      .. tostring(number), 2)
  end
  local scenario = self.scenarios.starters[number]
  local moves = source.moves and copy(source.moves)
    or self:_moveSlots(
      source.moveNumbers
        or (scenario and scenario.moves)
        or { self.scenarios.defaultMoveNumber }
    )
  return PokemonInstance.new(species, {
    level = source.level,
    nickname = source.nickname,
    heldItemId = source.heldItemId,
    currentHP = source.currentHP,
    experience = source.experience,
    dvs = source.dvs,
    moves = moves,
  })
end

function BattleRequestFactory:_playerParty()
  local result = {}
  for index, member in ipairs(self.gameSession.party.members) do
    result[index] = self:_pokemon(member)
  end
  if #result == 0 then
    error("battle request factory: player party is empty", 2)
  end
  return result
end

function BattleRequestFactory:_rival(playerParty)
  local playerNumber = self:_number(playerParty[1].speciesId)
  local starter = self.scenarios.starters[playerNumber]
  if not starter then
    error("battle request factory: rival requires a starter lead", 2)
  end
  local rival = self.scenarios.starters[starter.rival]
  return {
    self:_pokemon({
      speciesNumber = starter.rival,
      level = 5,
      moveNumbers = rival.moves,
      dvs = { attack = 0, defense = 0, speed = 0, special = 0 },
    }),
  }
end

function BattleRequestFactory:_opponentParty(request, playerParty)
  local options = request.options or {}
  if type(options.party) == "table" and #options.party > 0 then
    local result = {}
    for index, member in ipairs(options.party) do
      result[index] = self:_pokemon(member)
    end
    return result
  end
  if request.kind == "trainer" then
    if request.opponentId == "crystal.trainer.rival.lab" then
      return self:_rival(playerParty)
    end
    error("battle request factory: unknown trainer "
      .. tostring(request.opponentId), 2)
  end
  local default = self.scenarios.wildDefaults[slug(request.opponentId)]
  return {
    self:_pokemon({
      speciesId = options.speciesId or request.opponentId,
      speciesNumber = options.speciesNumber
        or (default and default.speciesNumber),
      level = options.level or (default and default.level) or 2,
      moveNumbers = options.moveNumbers
        or (default and default.moves),
      dvs = options.dvs,
    }),
  }
end

function BattleRequestFactory:create(request)
  if type(request) ~= "table"
      or (request.kind ~= "wild" and request.kind ~= "trainer") then
    error("battle request factory: request kind must be wild or trainer", 2)
  end
  local playerParty = self:_playerParty()
  return BattleSession.new(self.registry, {
    kind = request.kind,
    seed = request.options and request.options.seed,
    playerParty = playerParty,
    opponentParty = self:_opponentParty(request, playerParty),
    aiProfileId = request.options and request.options.aiProfileId,
  })
end

local function persistentPokemon(pokemon)
  return {
    nickname = pokemon.nickname,
    currentHP = pokemon.currentHP,
    experience = pokemon.experience,
    dvs = copy(pokemon.dvs),
    moves = copy(pokemon.moves),
  }
end

function BattleRequestFactory:commit(session)
  for index, pokemon in ipairs(session.state.player.party) do
    local member = self.gameSession.party.members[index]
    if member then
      member.level = pokemon.level
      member.nickname = pokemon.nickname
      member.currentHP = pokemon.currentHP
      member.experience = pokemon.experience
      member.dvs = copy(pokemon.dvs)
      member.moves = copy(pokemon.moves)
    end
  end
  for _, pokemon in ipairs(session.state.opponent.party) do
    self.gameSession:markSeen(stableSpeciesId(pokemon.speciesId))
  end
  if session.state.outcome == "caught" then
    local caught = session.state.opponent:active()
    local persistentId = stableSpeciesId(caught.speciesId)
    self.gameSession:markCaught(persistentId)
    local stored = persistentPokemon(caught)
    self.gameSession.party:give(
      persistentId,
      caught.level,
      caught.heldItemId,
      stored
    )
  end
  return {
    outcome = session.state.outcome,
    won = session.state.outcome == "player_win",
    caught = session.state.outcome == "caught",
    escaped = session.state.outcome == "escaped",
  }
end

return BattleRequestFactory
