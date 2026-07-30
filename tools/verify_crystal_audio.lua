local AudioRuntime = require("src.audio.AudioRuntime")
local AudioService = require("src.script.AudioService")
local CrystalBattleData = require("src.import.CrystalBattleData")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then error("could not open ROM: " .. tostring(message), 2) end
  local data = file:read("*a")
  file:close()
  return data
end

local function requireValue(condition, message)
  if not condition then
    error("M5-012 verification failed: " .. message, 2)
  end
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then return 2 end
  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local battle = CrystalBattleData.extract(
    Rom.new(data), identity.profile)
  data = nil
  local calls = {}
  local sink = {}
  for _, method in ipairs({
    "playMusic", "stopMusic", "playSfx", "playCry",
  }) do
    sink[method] = function(_, id)
      calls[#calls + 1] = { method = method, id = id }
    end
  end
  local service = AudioService.new()
  local runtime = AudioRuntime.new(service, sink)
  service:playMusic("crystal.music.violet_city_and_routes")
  service:playSfx("crystal.sfx.menu_open")
  service:playCry(battle.species[155].id)
  runtime:update()
  requireValue(#calls == 3, "audio events were not dispatched")
  requireValue(calls[1].method == "playMusic"
      and calls[2].method == "playSfx"
      and calls[3].method == "playCry",
    "audio event ordering changed")
  requireValue(calls[3].id:match("cyndaquil$"),
    "battle cry did not use the ROM-derived species identity")
  runtime:update()
  requireValue(#calls == 3, "audio events replayed twice")
  io.write(("M5-012 verified %s: music, SFX, and cry scheduling\n")
    :format(identity.profile.id))
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result), "\n")
  os.exit(1)
end
os.exit(result)
