local BattleBridge = require("src.battle.BattleBridge")
local BattleRequestFactory =
  require("src.battle.BattleRequestFactory")
local CrystalBattleData =
  require("src.import.CrystalBattleData")
local DataRegistry = require("src.pokemon.DataRegistry")
local GameSession = require("src.game.GameSession")
local RawRetentionAudit =
  require("src.import.RawRetentionAudit")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local StateStack = require("src.core.StateStack")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then
    error("could not open supplied ROM: " .. tostring(message), 2)
  end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-004 verification failed: " .. message, 2)
  end
end

local function input(action)
  return {
    wasPressed = function(_, candidate)
      return action == candidate
    end,
  }
end

local function closeMessages(scene)
  local guard = 0
  while scene.presentation:model().kind == "message" do
    guard = guard + 1
    requireValue(guard <= 50, "battle messages did not terminate")
    scene:update(0, input("confirm"))
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_battle_bridge.lua <path-to-ROM>\n"
    )
    return 2
  end

  local bytes = readRom(path)
  local identity = RomIdentifier.inspect(bytes)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(bytes)
  bytes = nil
  local data = CrystalBattleData.extract(rom, identity.profile)
  requireValue(
    RawRetentionAudit.inspect(rom, data).status == "passed",
    "normalized battle data retained raw ROM ranges"
  )
  rom = nil

  local registry = DataRegistry.new(data)
  local game = GameSession.new(identity.profile.id)
  game.party:give(
    "crystal.species.cyndaquil",
    5,
    "crystal.item.berry"
  )
  local states = StateStack.new()
  local worldState = { opaque = true }
  states:push(worldState)
  local bridge = BattleBridge.new(
    states,
    BattleRequestFactory.new(registry, data, game)
  )
  local result
  local scene = bridge:start({
    kind = "wild",
    opponentId = "crystal.species.pidgey",
    options = { seed = 9473 },
  }, function(value) result = value end)
  requireValue(states:current() == scene,
    "battle scene was not pushed over the world")

  closeMessages(scene)
  local turns = 0
  while scene.session.state.phase ~= "complete" do
    turns = turns + 1
    requireValue(turns <= 100, "visible bridge battle exceeded 100 turns")
    requireValue(scene.presentation:model().kind == "root",
      "bridge did not return to root command menu")
    scene:update(0, input("confirm"))
    local moves = scene.presentation:model()
    requireValue(moves.kind == "moves",
      "Fight did not open move menu")
    local selected
    for index, move in ipairs(moves.options) do
      if not move.disabled then selected = index break end
    end
    requireValue(selected ~= nil, "starter has no usable move")
    while scene.presentation.listIndex ~= selected do
      scene:update(0, input("down"))
    end
    scene:update(0, input("confirm"))
    closeMessages(scene)
  end
  requireValue(
    scene.presentation:model().outcome == "player_win",
    "bridge battle did not reach player win"
  )
  scene:update(0, input("confirm"))
  requireValue(states:current() == worldState,
    "battle scene did not pop back to world")
  requireValue(result and result.won,
    "script-facing result did not report the win")
  requireValue(bridge.active == nil,
    "bridge retained a completed battle")

  local member = game.party.members[1]
  requireValue(
    member.currentHP and member.experience and #member.moves == 2,
    "persistent party state did not receive battle changes"
  )
  requireValue(game.pokedex.seen["crystal.species.pidgey"],
    "encountered species was not marked seen")
  local restored = GameSession.new(identity.profile.id, {
    snapshot = game:snapshot(),
  })
  requireValue(
    restored.party.members[1].currentHP == member.currentHP
      and restored.party.members[1].moves[1].pp
        == member.moves[1].pp,
    "battle state did not survive session snapshot restore"
  )

  print("Crystal M5-004 battle-bridge verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Flow: world -> visible wild battle -> world")
  print("Result: player_win returned to coroutine adapter")
  print("Persistence: HP, EXP, PP, moves, and Pokedex seen retained")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
