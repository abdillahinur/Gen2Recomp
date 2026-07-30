local CrystalFont = require("src.import.CrystalFont")
local CrystalSpecies = require("src.import.CrystalSpecies")
local CrystalTileset = require("src.import.CrystalTileset")
local CrystalWorldData = require("src.import.CrystalWorldData")
local Json = require("src.core.Json")
local RawRetentionAudit = require("src.import.RawRetentionAudit")
local Rom = require("src.import.Rom")
local RomIdentifier = require("src.import.RomIdentifier")

local CrystalImporter = {}

local DEFAULT_EXTRACTORS = {
  font = CrystalFont.extract,
  species = CrystalSpecies.extract,
  tileset = CrystalTileset.extractJohto,
  world = CrystalWorldData.extract,
}

local PAYLOADS = {
  { id = "font", path = "data/font.json", kind = "font" },
  { id = "species", path = "data/species.json", kind = "species" },
  {
    id = "tileset",
    path = "data/tilesets/johto.json",
    kind = "tileset",
  },
  { id = "world", path = "data/world/new_bark.json", kind = "world" },
}

local function arrayCopy(values)
  local result = Json.array({})
  for _, value in ipairs(values or {}) do
    result[#result + 1] = value
  end
  return result
end

local function emit(callback, fraction, step, message)
  if callback then
    callback({
      fraction = fraction,
      percent = math.floor(fraction * 100 + 0.5),
      step = step,
      message = message,
    })
  end
end

local function checkCancellation(token)
  if token and token:isCancelled() then
    error("Crystal import cancelled: "
      .. tostring(token:getReason() or "cancelled"), 3)
  end
end

local function profileSummary(profile)
  local reference = profile.reference or {}
  return {
    id = profile.id,
    family = profile.family,
    displayName = profile.displayName,
    cacheSchema = profile.cacheSchema,
    reference = {
      repository = reference.repository,
      sourceCommit = reference.sourceCommit,
      symbolsCommit = reference.symbolsCommit,
      rgbdsVersion = reference.rgbdsVersion,
    },
  }
end

local function headerSummary(header)
  if not header then
    return Json.null
  end
  return {
    title = header.title,
    manufacturerCode = header.manufacturerCode,
    cgbFlag = header.cgbFlag,
    cartridgeType = header.cartridgeType,
    romSizeCode = header.romSizeCode,
    ramSizeCode = header.ramSizeCode,
    destinationCode = header.destinationCode,
    version = header.version,
    headerChecksumValid = header.headerChecksumValid,
    globalChecksumValid = header.globalChecksumValid,
  }
end

local function rejectionReport(identity)
  return {
    schema = 1,
    status = "rejected",
    rom = {
      size = identity.size,
      sha1 = identity.sha1,
      header = headerSummary(identity.header),
    },
    errors = arrayCopy(identity.errors),
    warnings = arrayCopy(identity.warnings),
    sections = Json.array({}),
    payloads = Json.array({}),
  }
end

local function countFontTiles(font)
  local count = 0
  for _, set in ipairs(font.sets or {}) do
    count = count + #(set.tiles or {})
  end
  return count
end

local function structuralReport(identity, extracted)
  local font = extracted.font
  local species = extracted.species
  local tileset = extracted.tileset
  local world = extracted.world
  local mapCount = 0
  for _, group in ipairs(world.groups or {}) do
    mapCount = mapCount + #(group.maps or {})
  end
  return {
    schema = 1,
    status = "complete",
    profile = profileSummary(identity.profile),
    rom = {
      size = identity.size,
      sha1 = identity.sha1,
      header = headerSummary(identity.header),
    },
    errors = Json.array({}),
    warnings = arrayCopy(identity.warnings),
    sections = Json.array({
      {
        id = "font",
        schema = font.schema,
        setCount = #(font.sets or {}),
        tileCount = countFontTiles(font),
      },
      {
        id = "species",
        schema = species.schema,
        recordCount = species.count or #(species.records or {}),
      },
      {
        id = "tileset",
        schema = tileset.schema,
        tilesetId = tileset.id,
        graphicTileCount =
          tileset.graphics and tileset.graphics.tileCount or 0,
        tileSlotCount = #(tileset.tileSlots or {}),
        metatileCount =
          tileset.metatiles and tileset.metatiles.count or 0,
        collisionRecordCount =
          tileset.collision and tileset.collision.count or 0,
      },
      {
        id = "world",
        schema = world.schema,
        groupCount = #(world.groups or {}),
        mapCount = mapCount,
        collisionPermissionCount =
          #(world.collisionPermissions or {}),
        spriteCount = #(world.sprites or {}),
      },
    }),
    payloads = Json.array({
      { path = PAYLOADS[1].path, kind = PAYLOADS[1].kind },
      { path = PAYLOADS[2].path, kind = PAYLOADS[2].kind },
      { path = PAYLOADS[3].path, kind = PAYLOADS[3].kind },
      { path = PAYLOADS[4].path, kind = PAYLOADS[4].kind },
      { path = "reports/import.json", kind = "report" },
    }),
  }
end

local function abortActive(transaction)
  if transaction
      and transaction.state ~= "committed"
      and transaction.state ~= "reused"
      and transaction.state ~= "aborted" then
    pcall(function() transaction:abort() end)
  end
end

function CrystalImporter.run(data, cacheStore, options)
  options = options or {}
  if type(cacheStore) ~= "table"
      or type(cacheStore.begin) ~= "function" then
    error("Crystal importer requires a cache store", 2)
  end
  if options.onProgress ~= nil
      and type(options.onProgress) ~= "function" then
    error("Crystal importer progress callback must be a function", 2)
  end

  local identifier = options.identifier or RomIdentifier
  local extractors = options.extractors or DEFAULT_EXTRACTORS
  local cancellationToken = options.cancellationToken
  local transaction

  local ok, resultOrError = pcall(function()
    checkCancellation(cancellationToken)
    emit(options.onProgress, 0, "identify", "Identifying ROM")
    local identity = identifier.inspect(data, options.registry)
    checkCancellation(cancellationToken)

    if not identity.accepted then
      local report = rejectionReport(identity)
      emit(options.onProgress, 1, "rejected", "ROM rejected")
      return {
        ok = false,
        report = report,
      }
    end

    local rom = Rom.new(data)
    data = nil
    emit(options.onProgress, 0.10, "font", "Decoding font")
    checkCancellation(cancellationToken)
    local extracted = {}
    extracted.font = extractors.font(rom, identity.profile)

    emit(options.onProgress, 0.35, "species", "Decoding species")
    checkCancellation(cancellationToken)
    extracted.species = extractors.species(rom, identity.profile)

    emit(options.onProgress, 0.55, "tileset", "Decoding Johto tileset")
    checkCancellation(cancellationToken)
    extracted.tileset = extractors.tileset(rom, identity.profile)

    emit(options.onProgress, 0.72, "world", "Decoding New Bark world")
    checkCancellation(cancellationToken)
    extracted.world = extractors.world(rom, identity.profile)

    emit(options.onProgress, 0.82, "audit", "Auditing decoded data")
    checkCancellation(cancellationToken)
    local retentionAudit = RawRetentionAudit.inspect(rom, extracted)
    rom = nil

    emit(options.onProgress, 0.87, "serialize", "Serializing cache data")
    checkCancellation(cancellationToken)
    local report = structuralReport(identity, extracted)
    report.rawRetentionAudit = retentionAudit
    local encoded = {}
    for _, payload in ipairs(PAYLOADS) do
      encoded[payload.id] = Json.encode(extracted[payload.id])
    end
    encoded.report = Json.encode(report)
    extracted = nil

    emit(options.onProgress, 0.94, "cache", "Promoting cache")
    checkCancellation(cancellationToken)
    transaction = cacheStore:begin(identity.profile, {
      cancellationToken = cancellationToken,
    })
    for _, payload in ipairs(PAYLOADS) do
      transaction:write(
        payload.path,
        payload.kind,
        encoded[payload.id]
      )
    end
    transaction:write(
      "reports/import.json",
      "report",
      encoded.report
    )
    encoded = nil

    local target, cacheStatus, manifest = transaction:commit()
    local warning = transaction.warning
    transaction = nil
    emit(options.onProgress, 1, "complete", "Import complete")
    return {
      ok = true,
      report = report,
      cache = {
        path = target,
        status = cacheStatus,
        warning = warning or Json.null,
        fileCount = manifest.fileCount,
        totalBytes = manifest.totalBytes,
      },
    }
  end)

  if not ok then
    abortActive(transaction)
    error(resultOrError, 0)
  end
  return resultOrError
end

CrystalImporter.PAYLOADS = PAYLOADS

return CrystalImporter
