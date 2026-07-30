local BattleSession = require("src.battle.BattleSession")
local PokemonInstance = require("src.pokemon.PokemonInstance")

local CrystalBattleGates = {}

local STARTERS = {
  [152] = { rival = 155, moves = { 33, 45 } },
  [155] = { rival = 158, moves = { 33, 43 } },
  [158] = { rival = 152, moves = { 10, 43 } },
}

local function moveSlots(registry, data, numbers)
  local slots = {}
  for index, number in ipairs(numbers) do
    local id = data.moveIds[number]
    local move = registry:get("moves", id)
    slots[index] = { id = id, pp = move.pp }
  end
  return slots
end

local function pokemon(registry, data, speciesNumber, level, moves, dvs)
  return PokemonInstance.new(
    registry:get("species", data.speciesIds[speciesNumber]),
    {
      level = level,
      moves = moveSlots(registry, data, moves),
      dvs = dvs,
    }
  )
end

function CrystalBattleGates.firstRival(registry, data, starterNumber, options)
  options = options or {}
  local starter = STARTERS[starterNumber]
  if not starter then
    error("Crystal battle gate: starter must be 152, 155, or 158", 2)
  end
  local rival = STARTERS[starter.rival]
  return BattleSession.new(registry, {
    kind = "trainer",
    seed = options.seed or 23063,
    playerParty = {
      pokemon(registry, data, starterNumber, 5, starter.moves, {
        attack = 15, defense = 15, speed = 15, special = 15,
      }),
    },
    opponentParty = {
      pokemon(registry, data, starter.rival, 5, rival.moves, {
        attack = 0, defense = 0, speed = 0, special = 0,
      }),
    },
    aiProfileId = "battle.ai.basic",
  })
end

function CrystalBattleGates.route29Wild(registry, data, starterNumber, options)
  options = options or {}
  local starter = STARTERS[starterNumber]
  if not starter then
    error("Crystal battle gate: starter must be 152, 155, or 158", 2)
  end
  return BattleSession.new(registry, {
    kind = "wild",
    seed = options.seed or 9473,
    playerParty = {
      pokemon(registry, data, starterNumber, 5, starter.moves, {
        attack = 15, defense = 15, speed = 15, special = 15,
      }),
    },
    opponentParty = {
      pokemon(registry, data, 16, 2, { 33 }, {
        attack = 0, defense = 0, speed = 0, special = 0,
      }),
    },
    aiProfileId = "battle.ai.basic",
  })
end

return CrystalBattleGates
