local CrystalWorldData = require("src.import.CrystalWorldData")
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

function CrystalPreview.load(path)
  local data = readFile(path)
  local identity = RomIdentifier.inspect(data)
  if not identity.accepted then
    error("preview ROM was rejected: "
      .. table.concat(identity.errors or {}, "; "), 2)
  end
  local rom = Rom.new(data)
  data = nil
  local world = CrystalWorldData.extract(rom, identity.profile)
  rom = nil
  return world, identity.profile
end

return CrystalPreview
