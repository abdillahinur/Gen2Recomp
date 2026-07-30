local BattleRng = require("src.battle.BattleRng")
local BattleSide = require("src.battle.BattleSide")

local BattleState = {}
BattleState.__index = BattleState

local KINDS = { wild = true, trainer = true }

local function pokemonSnapshot(pokemon)
  return {
    speciesId = pokemon.speciesId,
    level = pokemon.level,
    currentHP = pokemon.currentHP,
    maximumHP = pokemon.stats.hp,
    status = pokemon.status,
  }
end

local function sideSnapshot(side)
  local party = {}
  for index, pokemon in ipairs(side.party) do
    party[index] = pokemonSnapshot(pokemon)
  end
  return {
    id = side.id,
    activeIndex = side.activeIndex,
    party = party,
  }
end

function BattleState.new(options)
  options = options or {}
  if not KINDS[options.kind] then
    error("battle state: kind must be wild or trainer", 2)
  end
  local rng = options.rng or BattleRng.new(options.seed)
  if type(rng) ~= "table"
      or type(rng.nextByte) ~= "function"
      or type(rng.range) ~= "function" then
    error("battle state: RNG must provide nextByte and range", 2)
  end
  return setmetatable({
    kind = options.kind,
    rng = rng,
    player = BattleSide.new("player", options.playerParty),
    opponent = BattleSide.new("opponent", options.opponentParty),
    phase = "command",
    turn = 1,
    outcome = nil,
    pendingActions = {},
    events = {},
  }, BattleState)
end

function BattleState:emit(kind, data)
  local event = {
    index = #self.events + 1,
    turn = self.turn,
    kind = kind,
    data = data or {},
  }
  self.events[#self.events + 1] = event
  return event
end

function BattleState:snapshot()
  return {
    kind = self.kind,
    phase = self.phase,
    turn = self.turn,
    outcome = self.outcome,
    rngDraws = self.rng.draws,
    player = sideSnapshot(self.player),
    opponent = sideSnapshot(self.opponent),
    eventCount = #self.events,
  }
end

return BattleState
