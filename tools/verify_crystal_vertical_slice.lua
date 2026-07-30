local BattleRequestFactory =
  require("src.battle.BattleRequestFactory")
local CrystalBattleData = require("src.import.CrystalBattleData")
local CrystalTextData = require("src.import.CrystalTextData")
local CrystalWorldData = require("src.import.CrystalWorldData")
local DataRegistry = require("src.pokemon.DataRegistry")
local GameSession = require("src.game.GameSession")
local NativeSaveCodec = require("src.save.NativeSaveCodec")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local RtcPersistence = require("src.save.RtcPersistence")
local VerticalSliceRoute =
  require("src.acceptance.VerticalSliceRoute")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then error("could not open ROM: " .. tostring(message), 2) end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-014 verification failed: " .. message, 2)
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then return 2 end
  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(data)
  data = nil
  local worldData =
    CrystalWorldData.extract(rom, identity.profile)
  local battleData =
    CrystalBattleData.extract(rom, identity.profile)
  local textData =
    CrystalTextData.extract(rom, identity.profile)
  rom = nil
  requireValue(textData.count == 119,
    "required ROM dialogue catalog is incomplete")

  local route = VerticalSliceRoute.run(worldData, textData)
  requireValue(#route.stages == 5 and route.textCount >= 30,
    "acceptance route did not traverse all story stages")
  requireValue(route.game.state:hasFlag("crystal.badge.zephyr"),
    "acceptance route did not earn Zephyr Badge")

  local registry = DataRegistry.new(battleData)
  local factory = BattleRequestFactory.new(
    registry, battleData, route.game, {
      trainers = worldData.trainers,
    })
  local falkner = factory:create({
    kind = "trainer",
    opponentId = "crystal.trainer.01.001",
    options = { aiProfileId = "battle.ai.smart" },
  })
  requireValue(#falkner.state.opponent.party == 2,
    "acceptance route could not construct the native leader battle")

  local encoded = NativeSaveCodec.encode(
    identity.profile.id, route.game:snapshot(), 1000)
  local snapshot, savedAt =
    NativeSaveCodec.decode(encoded, identity.profile.id)
  local reconciled =
    RtcPersistence.reconcile(snapshot, savedAt, 1060)
  local restored = GameSession.new(identity.profile.id, {
    snapshot = reconciled,
  })
  requireValue(restored.state:hasFlag("crystal.badge.zephyr")
      and restored.player.mapId == "10:7"
      and restored.inventory:count("crystal.item.tm31") == 1,
    "first-badge state did not survive save/reload")

  io.write(("M5-014 verified %s: introduction-to-Zephyr-Badge "
    .. "route, %d exact ROM text requests, save/reload\n")
    :format(identity.profile.id, route.textCount))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result), "\n")
  os.exit(1)
end
os.exit(result)
