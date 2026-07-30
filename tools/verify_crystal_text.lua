local CrystalTextData = require("src.import.CrystalTextData")
local DialogueService = require("src.script.DialogueService")
local PresentationController =
  require("src.ui.PresentationController")
local RawRetentionAudit =
  require("src.import.RawRetentionAudit")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")
local RomTextProvider = require("src.ui.RomTextProvider")
local ScriptState = require("src.script.ScriptState")
local SemanticTextProvider =
  require("src.ui.SemanticTextProvider")

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
    error("M5-002 verification failed: " .. message, 2)
  end
end

local function input(action)
  return {
    wasPressed = function(_, candidate)
      return action == candidate
    end,
  }
end

local function main()
  local path = arg and arg[1]
  if not path or path == "" then
    io.stderr:write(
      "usage: lua tools/verify_crystal_text.lua <path-to-ROM>\n"
    )
    return 2
  end

  local data = readRom(path)
  local identity = RomIdentifier.inspect(data)
  requireValue(identity.accepted, table.concat(identity.errors, "; "))
  local rom = Rom.new(data)
  data = nil
  local catalog = CrystalTextData.extract(rom, identity.profile)
  requireValue(catalog.profileId == identity.profile.id,
    "catalog profile identity changed")

  local expected = 0
  for _ in pairs(identity.profile.text.entries) do expected = expected + 1 end
  requireValue(catalog.count == expected and catalog.count == 109,
    "catalog entry count is incomplete")
  for id, entry in pairs(catalog.entries) do
    requireValue(type(id) == "string" and #entry.tokens > 0
        or id == "crystal.text.introduction.oak_3",
      "decoded entry has no presentation tokens")
    requireValue(
      entry.terminal == "done"
        or entry.terminal == "prompt"
        or entry.terminal == "end",
      "decoded entry has no supported terminal"
    )
  end

  local audit = RawRetentionAudit.inspect(rom, catalog)
  requireValue(audit.status == "passed",
    "normalized catalog retained a raw ROM range")
  rom = nil

  local state = ScriptState.new()
  state:setVariable("player.name", "NOVA")
  local provider = RomTextProvider.forState(catalog, state)
  local fallback = SemanticTextProvider.new()
  for id in pairs(catalog.entries) do
    local pages = provider:resolvePages(id, {
      species = "crystal.species.cyndaquil",
    })
    requireValue(#pages >= 1, id .. " did not produce a visible page")
    for _, page in ipairs(pages) do
      requireValue(type(page) == "string",
        id .. " produced a non-string page")
      local lineCount = 1
      for _ in page:gmatch("\n") do lineCount = lineCount + 1 end
      requireValue(lineCount <= 2,
        id .. " exceeded the two-line dialogue viewport")
    end
    if id ~= "crystal.text.introduction.oak_3" then
      requireValue(provider:resolve(id) ~= fallback:resolve(id),
        id .. " fell back to a semantic label")
    end
  end

  local dialogue = DialogueService.new()
  local presentation = PresentationController.new(
    { dialogue = dialogue },
    { textProvider = provider }
  )
  dialogue:text({ id = "crystal.text.introduction.oak_1" })
  local first = presentation:model()
  requireValue(first.kind == "text" and first.pageCount > 1,
    "ROM dialogue did not expose multiple visible pages")
  local advances = 0
  while dialogue.active do
    advances = advances + 1
    requireValue(advances <= 20, "dialogue pagination did not terminate")
    presentation:update(input("confirm"))
  end
  requireValue(advances == first.pageCount,
    "dialogue request closed before every page was shown")

  print("Crystal M5-002 ROM-text verification passed.")
  print("Profile: " .. identity.profile.id)
  print("Catalog: 109 ROM-owned semantic mappings decoded")
  print("Presentation: two-line pagination and substitutions verified")
  print("Retention: normalized catalog contains no raw ROM ranges")
  return 0
end

local ok, result = pcall(main)
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  os.exit(1)
end
os.exit(result)
