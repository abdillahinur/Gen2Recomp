local CoverageReport = require("src.script.CoverageReport")
local CrystalWorldData = require("src.import.CrystalWorldData")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local ScriptCatalog = require("src.script.ScriptCatalog")

local function readRom(path)
  local file, message = io.open(path, "rb")
  if not file then error("could not open supplied ROM: " .. tostring(message)) end
  local data = file:read("*a")
  file:close()
  return data
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/report_script_coverage.lua <path-to-ROM>\n"
    )
    return 2
  end
  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  if not identity.accepted then
    error(table.concat(identity.errors, "; "))
  end
  local worldData =
    CrystalWorldData.extract(Rom.new(data), identity.profile)
  data = nil
  local report =
    CoverageReport.generate(worldData, ScriptCatalog.load())
  local summary = report.summary

  print("Crystal native-script coverage report.")
  print("Profile: " .. identity.profile.id)
  print(("Definitions (flow/map): %d (%d/%d)"):format(
    summary.definitions,
    summary.flowScripts,
    summary.mapScripts
  ))
  print(("Scripted maps: %d/%d (%.1f%%)"):format(
    summary.maps.covered,
    summary.maps.available,
    summary.maps.percent
  ))
  print(("Callbacks implemented/declared: %d/%d"):format(
    summary.callbacks.implemented,
    summary.callbacks.declared
  ))
  print(("Map scenes implemented/declared: %d/%d"):format(
    summary.scenes.implemented,
    summary.scenes.declared
  ))
  print("Flow scene beats declared: " .. summary.scenes.flowBeats)
  print(("Actor bindings resolved/declared: %d/%d"):format(
    summary.actors.resolved,
    summary.actors.declared
  ))
  for _, kind in ipairs({ "coordEvents", "bgEvents", "objects" }) do
    local value = summary.interactions[kind]
    print(("%s declared/available: %d/%d (%.1f%%)"):format(
      kind,
      value.declared,
      value.available,
      value.percent
    ))
  end
  for _, map in ipairs(report.maps) do
    if map.scriptId ~= require("src.core.Json").null then
      print(("Map %s %s: %s"):format(
        map.id,
        map.name,
        map.status
      ))
    end
  end
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
