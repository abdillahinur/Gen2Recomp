local GameSession = require("src.game.GameSession")
local NativeSaveCodec = require("src.save.NativeSaveCodec")
local RomIdentifier = require("src.import.RomIdentifier")
local RtcPersistence = require("src.save.RtcPersistence")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then error("could not open ROM: " .. tostring(message), 2) end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-011 verification failed: " .. message, 2)
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then return 2 end
  local identity = RomIdentifier.inspect(readRom(path))
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local game = GameSession.new(identity.profile.id, {
    money = 3000,
    clock = { hour = 23, minute = 55, weekday = 6 },
    player = { mapId = "10:5", x = 9, y = 17, facing = "up" },
  })
  game.party:give("crystal.species.cyndaquil", 5)
  game.inventory:give("crystal.item.potion", 2)
  local encoded = NativeSaveCodec.encode(
    identity.profile.id, game:snapshot(), 1000)
  local decoded, savedAt =
    NativeSaveCodec.decode(encoded, identity.profile.id)
  local reconciled, report =
    RtcPersistence.reconcile(decoded, savedAt, 1600)
  local restored = GameSession.new(identity.profile.id, {
    snapshot = reconciled,
  })
  requireValue(restored.money == 3000
      and restored.player.mapId == "10:5"
      and restored.player.facing == "up",
    "session progression or location did not restore")
  requireValue(restored.clock.hour == 0
      and restored.clock.minute == 5
      and restored.clock.weekday == 0,
    "RTC did not cross midnight and weekday correctly")
  requireValue(report.elapsedSeconds == 600,
    "RTC elapsed-time report changed")
  local wrongProfile = pcall(
    NativeSaveCodec.decode, encoded, "crystal_us_10")
  requireValue(not wrongProfile,
    "save was accepted for the wrong ROM revision")
  io.write(("M5-011 verified %s: versioned save and RTC restore\n")
    :format(identity.profile.id))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result), "\n")
  os.exit(1)
end
os.exit(result)
