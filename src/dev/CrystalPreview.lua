local CrystalWorldData = require("src.import.CrystalWorldData")
local CrystalTextData = require("src.import.CrystalTextData")
local CrystalFont = require("src.import.CrystalFont")
local CrystalIntroData = require("src.import.CrystalIntroData")
local CrystalAudioData = require("src.import.CrystalAudioData")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

local CrystalPreview = {}

local function readFile(path)
  local file, message = io.open(path, "rb")
  if not file then
    error("unable to open preview ROM: " .. tostring(message), 3)
  end
  local data = file:read("*a")
  file:close()
  return data
end

function CrystalPreview.load(path, options)
  options = options or {}
  local data = readFile(path)
  local identity = RomIdentifier.inspect(data)
  if not identity.accepted then
    error("preview ROM was rejected: "
      .. table.concat(identity.errors or {}, "; "), 2)
  end
  local rom = Rom.new(data)
  data = nil
  local world = CrystalWorldData.extract(rom, identity.profile)
  local text = CrystalTextData.extract(rom, identity.profile)
  local battle
  if options.battle then
    local CrystalBattleData =
      require("src.import.CrystalBattleData")
    battle = CrystalBattleData.extract(rom, identity.profile)
  end
  local battlePics
  if options.battlePics ~= false and options.battle then
    local CrystalBattlePics =
      require("src.import.CrystalBattlePics")
    battlePics = CrystalBattlePics.extract(
      rom, identity.profile, {
        species = options.battlePicSpecies,
      })
  end
  local presentation = {
    font = CrystalFont.extract(rom, identity.profile),
    intro = CrystalIntroData.extract(rom, identity.profile),
    audio = CrystalAudioData.extract(rom, identity.profile, battle),
    battlePics = battlePics,
  }
  rom = nil
  return world, identity.profile, text, battle, presentation
end

return CrystalPreview
