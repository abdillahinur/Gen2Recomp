local BattlePresentation =
  require("src.ui.BattlePresentation")
local CrystalBattleData =
  require("src.import.CrystalBattleData")
local CrystalBattleGates =
  require("src.battle.CrystalBattleGates")
local DataRegistry = require("src.pokemon.DataRegistry")
local RawRetentionAudit =
  require("src.import.RawRetentionAudit")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

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
    error("M5-003 verification failed: " .. message, 2)
  end
end

local function input(action)
  return {
    wasPressed = function(_, candidate)
      return action == candidate
    end,
  }
end

local function closeMessages(presentation, observed)
  local guard = 0
  while presentation:model().kind == "message" do
    guard = guard + 1
    requireValue(guard <= 40, "message queue did not terminate")
    observed.message = true
    presentation:update(input("confirm"))
  end
end

local function firstUsableMove(model)
  for index, option in ipairs(model.options) do
    if not option.disabled then return index end
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_battle_ui.lua <path-to-ROM>\n"
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
  local session =
    CrystalBattleGates.route29Wild(registry, data, 152)
  local completed
  local presentation = BattlePresentation.new(session, {
    onComplete = function(outcome) completed = outcome end,
  })
  local observed = {}
  local commands = 0
  closeMessages(presentation, observed)
  while session.state.phase ~= "complete" do
    commands = commands + 1
    requireValue(commands <= 100, "battle UI route exceeded 100 commands")
    local root = presentation:model()
    requireValue(root.kind == "root" and #root.options == 4,
      "root command menu is unavailable")
    observed.root = true
    presentation:update(input("confirm"))
    local moves = presentation:model()
    requireValue(moves.kind == "moves",
      "Fight did not open move selection")
    observed.moves = true
    local selected = firstUsableMove(moves)
    requireValue(selected ~= nil, "player has no selectable move")
    while presentation.listIndex ~= selected do
      presentation:update(input("down"))
    end
    presentation:update(input("confirm"))
    closeMessages(presentation, observed)
  end
  local terminal = presentation:model()
  requireValue(
    terminal.kind == "complete"
      and terminal.outcome == "player_win",
    "visible battle did not reach player-win presentation"
  )
  observed.complete = true
  presentation:update(input("confirm"))
  requireValue(completed == "player_win",
    "terminal acknowledgement did not call completion adapter")
  for _, kind in ipairs({ "message", "root", "moves", "complete" }) do
    requireValue(observed[kind],
      "route did not expose " .. kind .. " presentation")
  end

  print("Crystal M5-003 battle-presentation verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Scene: HUD, messages, root commands, and moves verified")
  print("Outcome: player_win acknowledged through visible state")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
