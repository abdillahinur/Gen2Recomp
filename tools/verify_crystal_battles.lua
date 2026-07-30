local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalBattleGates = require("src.battle.CrystalBattleGates")
local DataRegistry = require("src.pokemon.DataRegistry")
local Profiles = require("src.import.Profiles")
local RawRetentionAudit = require("src.import.RawRetentionAudit")
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
    error("M4 verification failed: " .. message, 2)
  end
end

local function eventCount(state, kind)
  local count = 0
  for _, event in ipairs(state.events) do
    if event.kind == kind then count = count + 1 end
  end
  return count
end

local function verifyCompleted(session, label)
  local outcome = session:runToCompletion(100)
  requireValue(outcome == "player_win",
    label .. " did not reach the deterministic player-win outcome")
  requireValue(session.state.phase == "complete",
    label .. " did not enter the complete phase")
  requireValue(eventCount(session.state, "battle.ended") == 1,
    label .. " did not emit exactly one terminal event")
  requireValue(eventCount(
    session.state, "battle.experience_gained") == 1,
    label .. " did not award exactly one experience result")
  return {
    outcome = outcome,
    turns = session.state.turn - 1,
    events = #session.state.events,
  }
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_battles.lua <path-to-ROM>\n"
    )
    return 2
  end

  local bytes = readRom(path)
  local identity = RomIdentifier.inspect(bytes)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  requireValue(Profiles.get(identity.profile.id) == identity.profile,
    "profile registry changed during verification")

  local rom = Rom.new(bytes)
  local data =
    CrystalBattleData.extract(rom, identity.profile)
  bytes = nil
  requireValue(#data.species == 251,
    "expected 251 decoded species")
  requireValue(#data.moves == 251,
    "expected 251 decoded moves")
  local retention = RawRetentionAudit.inspect(rom, data)
  requireValue(retention.status == "passed",
    "normalized battle data retained a raw ROM range")
  local registry = DataRegistry.new(data)

  local rival = verifyCompleted(
    CrystalBattleGates.firstRival(registry, data, 152),
    "first rival battle"
  )
  local wild = verifyCompleted(
    CrystalBattleGates.route29Wild(registry, data, 152),
    "Route 29 wild battle"
  )

  print("Crystal M4 battle verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Normalized species/moves: 251/251")
  print(("First rival: %s, %d turns, %d events")
    :format(rival.outcome, rival.turns, rival.events))
  print(("Route 29 wild: %s, %d turns, %d events")
    :format(wild.outcome, wild.turns, wild.events))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
