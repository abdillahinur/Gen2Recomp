local BuildInfo = require("src.core.BuildInfo")
local Json = require("src.core.Json")

local CacheManifest = {}

local FORMAT = "gen2recomp-cache"
local FORMAT_VERSION = 1
local COMPLETE_STATE = "complete"
local MANIFEST_FILENAME = "manifest.json"

local FORBIDDEN_EXTENSIONS = {
  gb = true,
  gbc = true,
  rtc = true,
  sav = true,
  sgb = true,
  srm = true,
}

local OWNER_FIELDS = {
  "applicationId",
  "profileId",
  "romSha1",
  "cacheSchema",
  "importerVersion",
}

local function isInteger(value, minimum)
  return type(value) == "number"
    and value == value
    and value % 1 == 0
    and (minimum == nil or value >= minimum)
end

local function isSha1(value)
  return type(value) == "string"
    and #value == 40
    and value:match("^[0-9a-f]+$") ~= nil
end

local function validateProfileId(value)
  return type(value) == "string"
    and value:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function validateRelativePath(path)
  if type(path) ~= "string" or path == "" then
    return false, "must be a non-empty string"
  end
  if path == MANIFEST_FILENAME then
    return false, "is reserved for the cache manifest"
  end
  if path:find("\\", 1, true) then
    return false, "must use forward slashes"
  end
  if path:sub(1, 1) == "/" or path:find(":", 1, true) then
    return false, "must be relative to the cache directory"
  end
  if path:find("[%z\1-\31\127]") then
    return false, "contains a control character"
  end

  for segment in path:gmatch("[^/]+") do
    if segment == "." or segment == ".." then
      return false, "contains a traversal segment"
    end
  end
  if path:find("//", 1, true) or path:sub(-1) == "/" then
    return false, "contains an empty path segment"
  end

  local extension = path:match("%.([^.]+)$")
  if extension and FORBIDDEN_EXTENSIONS[extension:lower()] then
    return false, "uses a forbidden ROM or cartridge-save extension"
  end
  return true
end

local function expectedOwner(profile, buildInfo)
  buildInfo = buildInfo or BuildInfo
  if type(profile) ~= "table" then
    error("cache owner requires a ROM profile", 3)
  end

  local owner = {
    applicationId = buildInfo.applicationId,
    profileId = profile.id,
    romSha1 = type(profile.sha1) == "string" and profile.sha1:lower() or nil,
    cacheSchema = profile.cacheSchema,
    importerVersion = buildInfo.importerVersion,
  }

  if type(owner.applicationId) ~= "string" or owner.applicationId == "" then
    error("build info is missing applicationId", 3)
  end
  if not validateProfileId(owner.profileId) then
    error("profile id is not safe for cache ownership", 3)
  end
  if not isSha1(owner.romSha1) then
    error("profile is missing a lowercase-compatible SHA-1", 3)
  end
  if not isInteger(owner.cacheSchema, 1) then
    error("profile cacheSchema must be a positive integer", 3)
  end
  if not isInteger(owner.importerVersion, 1) then
    error("build importerVersion must be a positive integer", 3)
  end

  return owner
end

local function appendOwnerErrors(errors, owner)
  if type(owner) ~= "table" then
    errors[#errors + 1] = "owner must be a table"
    return
  end
  if type(owner.applicationId) ~= "string" or owner.applicationId == "" then
    errors[#errors + 1] = "owner.applicationId must be a non-empty string"
  end
  if not validateProfileId(owner.profileId) then
    errors[#errors + 1] = "owner.profileId is invalid"
  end
  if not isSha1(owner.romSha1) then
    errors[#errors + 1] = "owner.romSha1 must be lowercase hexadecimal SHA-1"
  end
  if not isInteger(owner.cacheSchema, 1) then
    errors[#errors + 1] =
      "owner.cacheSchema must be a positive integer"
  end
  if not isInteger(owner.importerVersion, 1) then
    errors[#errors + 1] =
      "owner.importerVersion must be a positive integer"
  end
end

local function appendFileErrors(errors, files)
  if type(files) ~= "table" then
    errors[#errors + 1] = "files must be an array"
    return 0, 0
  end

  local seen = {}
  local totalBytes = 0
  local previousPath = nil

  for index, file in ipairs(files) do
    if type(file) ~= "table" then
      errors[#errors + 1] = ("files[%d] must be a table"):format(index)
    else
      local pathOk, pathError = validateRelativePath(file.path)
      if not pathOk then
        errors[#errors + 1] = ("files[%d].path %s")
          :format(index, pathError)
      else
        if seen[file.path] then
          errors[#errors + 1] = "duplicate cache file path: " .. file.path
        end
        if previousPath and file.path < previousPath then
          errors[#errors + 1] =
            "cache file inventory must be sorted by path"
        end
        seen[file.path] = true
        previousPath = file.path
      end

      if type(file.kind) ~= "string"
          or file.kind:match("^[a-z][a-z0-9_-]*$") == nil then
        errors[#errors + 1] = ("files[%d].kind is invalid"):format(index)
      end
      if not isInteger(file.size, 0) then
        errors[#errors + 1] =
          ("files[%d].size must be a non-negative integer"):format(index)
      else
        totalBytes = totalBytes + file.size
      end
      if not isSha1(file.sha1) then
        errors[#errors + 1] =
          ("files[%d].sha1 must be lowercase hexadecimal SHA-1")
          :format(index)
      end
    end
  end

  return #files, totalBytes
end

function CacheManifest.validate(manifest)
  local errors = {}
  if type(manifest) ~= "table" then
    return false, { "manifest must be a table" }
  end

  if manifest.format ~= FORMAT then
    errors[#errors + 1] = "unsupported cache manifest format"
  end
  if manifest.formatVersion ~= FORMAT_VERSION then
    errors[#errors + 1] = "unsupported cache manifest version"
  end
  if manifest.state ~= COMPLETE_STATE then
    errors[#errors + 1] = "cache manifest is not complete"
  end

  appendOwnerErrors(errors, manifest.owner)

  if type(manifest.producer) ~= "table"
      or type(manifest.producer.applicationVersion) ~= "string"
      or manifest.producer.applicationVersion == "" then
    errors[#errors + 1] =
      "producer.applicationVersion must be a non-empty string"
  end

  local fileCount, totalBytes = appendFileErrors(errors, manifest.files)
  if manifest.fileCount ~= fileCount then
    errors[#errors + 1] = "fileCount does not match the inventory"
  end
  if manifest.totalBytes ~= totalBytes then
    errors[#errors + 1] = "totalBytes does not match the inventory"
  end

  return #errors == 0, errors
end

function CacheManifest.new(profile, files, buildInfo)
  buildInfo = buildInfo or BuildInfo
  if type(files) ~= "table" then
    error("cache manifest files must be an array", 2)
  end

  local inventory = {}
  for index, file in ipairs(files) do
    if type(file) ~= "table" then
      error(("cache manifest file %d must be a table"):format(index), 2)
    end
    inventory[index] = {
      path = file.path,
      kind = file.kind,
      size = file.size,
      sha1 = type(file.sha1) == "string" and file.sha1:lower() or file.sha1,
    }
  end
  table.sort(inventory, function(left, right)
    return tostring(left.path) < tostring(right.path)
  end)

  local totalBytes = 0
  for _, file in ipairs(inventory) do
    if isInteger(file.size, 0) then
      totalBytes = totalBytes + file.size
    end
  end

  local manifest = {
    format = FORMAT,
    formatVersion = FORMAT_VERSION,
    state = COMPLETE_STATE,
    owner = expectedOwner(profile, buildInfo),
    producer = {
      applicationVersion = buildInfo.applicationVersion,
    },
    files = Json.array(inventory),
    fileCount = #inventory,
    totalBytes = totalBytes,
  }

  local valid, errors = CacheManifest.validate(manifest)
  if not valid then
    error("invalid cache manifest: " .. table.concat(errors, "; "), 2)
  end
  return manifest
end

function CacheManifest.matches(manifest, profile, buildInfo)
  local valid, errors = CacheManifest.validate(manifest)
  if not valid then
    return false, errors
  end

  local expected = expectedOwner(profile, buildInfo)
  local mismatches = {}
  for _, field in ipairs(OWNER_FIELDS) do
    if manifest.owner[field] ~= expected[field] then
      mismatches[#mismatches + 1] = "cache owner mismatch: " .. field
    end
  end
  return #mismatches == 0, mismatches
end

function CacheManifest.directory(profile, buildInfo)
  local owner = expectedOwner(profile, buildInfo)
  return ("cache/%s/%s/schema-%d/importer-%d")
    :format(
      owner.profileId,
      owner.romSha1,
      owner.cacheSchema,
      owner.importerVersion
    )
end

function CacheManifest.validateFilePath(path)
  return validateRelativePath(path)
end

CacheManifest.FORMAT = FORMAT
CacheManifest.FORMAT_VERSION = FORMAT_VERSION
CacheManifest.MANIFEST_FILENAME = MANIFEST_FILENAME

return CacheManifest
