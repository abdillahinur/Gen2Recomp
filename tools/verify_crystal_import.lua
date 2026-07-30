local CacheStore = require("src.import.CacheStore")
local CrystalImporter = require("src.import.CrystalImporter")
local Profiles = require("src.import.Profiles")
local MemoryFilesystem = require("tests.fixtures.MemoryFilesystem")

local function readRom(path)
  local file, openError = io.open(path, "rb")
  if not file then
    error("could not open supplied ROM: " .. tostring(openError), 2)
  end
  local data, readError = file:read("*a")
  file:close()
  if not data then
    error("could not read supplied ROM: " .. tostring(readError), 2)
  end
  return data
end

local function section(report, id)
  for _, candidate in ipairs(report.sections or {}) do
    if candidate.id == id then
      return candidate
    end
  end
  error("import report is missing section " .. id, 2)
end

local function main()
  local path = arg and arg[1]
  if type(path) ~= "string" or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_import.lua <path-to-ROM>\n"
    )
    return 2
  end

  local data = readRom(path)
  local filesystem = MemoryFilesystem.new()
  local store = CacheStore.new(filesystem, {
    tokenFactory = function() return "rom-gated-verification" end,
  })
  local lastPercent = -1
  local result = CrystalImporter.run(data, store, {
    onProgress = function(event)
      if event.percent ~= lastPercent then
        lastPercent = event.percent
        print(("%3d%%  %s"):format(event.percent, event.message))
      end
    end,
  })
  data = nil

  if not result.ok then
    io.stderr:write("ROM was rejected:\n")
    for _, message in ipairs(result.report.errors or {}) do
      io.stderr:write("  - " .. tostring(message) .. "\n")
    end
    return 1
  end

  local profileId = result.report.profile.id
  local profile = Profiles.get(profileId)
  if not profile then
    error("accepted profile disappeared from the registry", 2)
  end
  local valid, errors = store:validate(result.cache.path, profile)
  if not valid then
    error("in-memory cache validation failed: "
      .. table.concat(errors, "; "), 2)
  end

  local font = section(result.report, "font")
  local species = section(result.report, "species")
  local tileset = section(result.report, "tileset")

  print("")
  print("Crystal ROM-gated import verification passed.")
  print("Profile: " .. profileId)
  print("SHA-1: " .. result.report.rom.sha1)
  print(("Font tiles: %d"):format(font.tileCount))
  print(("Species records: %d"):format(species.recordCount))
  print(("Johto graphics/metatiles/collision: %d/%d/%d"):format(
    tileset.graphicTileCount,
    tileset.metatileCount,
    tileset.collisionRecordCount
  ))
  print(("Cache payloads/bytes: %d/%d"):format(
    result.cache.fileCount,
    result.cache.totalBytes
  ))
  print("The verification cache existed only in memory and was discarded.")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
