local BuildInfo = require("src.core.BuildInfo")
local CacheManifest = require("src.import.CacheManifest")
local CacheManifestCodec = require("src.import.CacheManifestCodec")
local Sha1 = require("src.import.Sha1")

local CacheStore = {}
CacheStore.__index = CacheStore

local Transaction = {}
Transaction.__index = Transaction

local tokenCounter = 0

local REQUIRED_FILESYSTEM_METHODS = {
  "info",
  "createDirectory",
  "write",
  "read",
  "list",
  "removeTree",
  "rename",
}

local function defaultToken()
  tokenCounter = tokenCounter + 1
  return ("%x-%d"):format(os.time(), tokenCounter)
end

local function requireSuccess(ok, message, context)
  if not ok then
    error(context .. ": " .. tostring(message or "operation failed"), 3)
  end
end

local function parent(path)
  return path:match("^(.*)/[^/]+$")
end

local function basename(path)
  return path:match("([^/]+)$")
end

local function appendUnique(result, seen, message)
  if not seen[message] then
    seen[message] = true
    result[#result + 1] = message
  end
end

local function validateToken(token)
  return type(token) == "string"
    and token:match("^[a-zA-Z0-9_-]+$") ~= nil
end

function CacheStore.new(filesystem, options)
  options = options or {}
  if type(filesystem) ~= "table" then
    error("cache store requires a filesystem", 2)
  end
  for _, method in ipairs(REQUIRED_FILESYSTEM_METHODS) do
    if type(filesystem[method]) ~= "function" then
      error("cache filesystem is missing " .. method, 2)
    end
  end

  return setmetatable({
    filesystem = filesystem,
    buildInfo = options.buildInfo or BuildInfo,
    tokenFactory = options.tokenFactory or defaultToken,
  }, CacheStore)
end

function CacheStore:validate(path, profile)
  local errors = {}
  local seenErrors = {}
  local filesystem = self.filesystem
  local directoryInfo = filesystem:info(path)
  if not directoryInfo or directoryInfo.type ~= "directory" then
    return false, { "cache directory does not exist" }
  end

  local manifestPath = path .. "/" .. CacheManifest.MANIFEST_FILENAME
  local source, readError = filesystem:read(manifestPath)
  if source == nil then
    return false, {
      "cache manifest could not be read: "
        .. tostring(readError or "missing file"),
    }
  end

  local decoded, manifestOrError =
    pcall(CacheManifestCodec.decode, source)
  if not decoded then
    return false, { tostring(manifestOrError) }
  end
  local manifest = manifestOrError
  local matches, ownershipErrors =
    CacheManifest.matches(manifest, profile, self.buildInfo)
  if not matches then
    for _, message in ipairs(ownershipErrors) do
      appendUnique(errors, seenErrors, message)
    end
  end

  local expectedFiles = {
    [CacheManifest.MANIFEST_FILENAME] = true,
  }
  local expectedDirectories = {}

  for _, file in ipairs(manifest.files) do
    expectedFiles[file.path] = true
    local directory = parent(file.path)
    while directory do
      expectedDirectories[directory] = true
      directory = parent(directory)
    end

    local payloadPath = path .. "/" .. file.path
    local info = filesystem:info(payloadPath)
    if not info or info.type ~= "file" then
      appendUnique(errors, seenErrors,
        "missing cache payload: " .. file.path)
    else
      if info.size ~= nil and info.size ~= file.size then
        appendUnique(errors, seenErrors,
          "cache payload size mismatch: " .. file.path)
      end
      local payload, payloadError = filesystem:read(payloadPath)
      if payload == nil then
        appendUnique(errors, seenErrors,
          "cache payload could not be read: " .. file.path
            .. ": " .. tostring(payloadError))
      else
        if #payload ~= file.size then
          appendUnique(errors, seenErrors,
            "cache payload size mismatch: " .. file.path)
        end
        if Sha1.hex(payload) ~= file.sha1 then
          appendUnique(errors, seenErrors,
            "cache payload SHA-1 mismatch: " .. file.path)
        end
      end
    end
  end

  local function inspectDirectory(relative)
    local absolute = relative == "" and path or path .. "/" .. relative
    local items, listError = filesystem:list(absolute)
    if not items then
      appendUnique(errors, seenErrors,
        "cache directory could not be listed: "
          .. relative .. ": " .. tostring(listError))
      return
    end

    for _, name in ipairs(items) do
      local child = relative == "" and name or relative .. "/" .. name
      local info = filesystem:info(path .. "/" .. child)
      if not info then
        appendUnique(errors, seenErrors,
          "cache entry disappeared during validation: " .. child)
      elseif info.type == "directory" then
        if not expectedDirectories[child] then
          appendUnique(errors, seenErrors,
            "unexpected cache directory: " .. child)
        end
        inspectDirectory(child)
      elseif info.type == "file" then
        if not expectedFiles[child] then
          appendUnique(errors, seenErrors,
            "unexpected cache file: " .. child)
        end
      else
        appendUnique(errors, seenErrors,
          "unsupported cache entry type: " .. child)
      end
    end
  end

  inspectDirectory("")
  return #errors == 0, errors, manifest
end

function CacheStore:begin(profile, options)
  options = options or {}
  local target = CacheManifest.directory(profile, self.buildInfo)
  local token
  local staging

  for _ = 1, 32 do
    token = self.tokenFactory()
    if not validateToken(token) then
      error("cache transaction token is unsafe", 2)
    end
    staging = target .. ".staging-" .. token
    if not self.filesystem:info(staging) then
      break
    end
    staging = nil
  end
  if not staging then
    error("could not allocate a unique cache staging directory", 2)
  end

  local ok, message = self.filesystem:createDirectory(staging)
  requireSuccess(ok, message, "could not create cache staging directory")

  return setmetatable({
    store = self,
    profile = profile,
    target = target,
    staging = staging,
    quarantine = target .. ".invalid-" .. token,
    files = {},
    paths = {},
    state = "building",
    cancellationToken = options.cancellationToken,
  }, Transaction)
end

function Transaction:checkCancellation()
  local token = self.cancellationToken
  if token and token:isCancelled() then
    local reason = token:getReason() or "cancelled"
    self:abort()
    error("cache transaction cancelled: " .. tostring(reason), 2)
  end
end

function Transaction:write(path, kind, data)
  if self.state ~= "building" then
    error("cache transaction is not writable", 2)
  end
  self:checkCancellation()
  local pathOk, pathError = CacheManifest.validateFilePath(path)
  if not pathOk then
    error("invalid cache payload path: " .. pathError, 2)
  end
  if self.paths[path] then
    error("cache payload path was written twice: " .. path, 2)
  end
  if type(kind) ~= "string" then
    error("cache payload kind must be a string", 2)
  end
  if type(data) ~= "string" then
    error("cache payload data must be a string", 2)
  end

  local payloadPath = self.staging .. "/" .. path
  local payloadParent = parent(payloadPath)
  if payloadParent then
    local ok, message =
      self.store.filesystem:createDirectory(payloadParent)
    requireSuccess(ok, message, "could not create cache payload directory")
  end

  local ok, message = self.store.filesystem:write(payloadPath, data)
  requireSuccess(ok, message, "could not write cache payload")

  self.paths[path] = true
  self.files[#self.files + 1] = {
    path = path,
    kind = kind,
    size = #data,
    sha1 = Sha1.hex(data),
  }
  return self
end

function Transaction:commit()
  if self.state ~= "building" then
    error("cache transaction cannot be committed from state " .. self.state, 2)
  end
  self:checkCancellation()

  local manifest = CacheManifest.new(
    self.profile,
    self.files,
    self.store.buildInfo
  )
  local encoded = CacheManifestCodec.encode(manifest)
  local manifestPath =
    self.staging .. "/" .. CacheManifest.MANIFEST_FILENAME
  local ok, message = self.store.filesystem:write(manifestPath, encoded)
  requireSuccess(ok, message, "could not write cache manifest")
  self.state = "finalized"

  local valid, validationErrors =
    self.store:validate(self.staging, self.profile)
  if not valid then
    error("staged cache validation failed: "
      .. table.concat(validationErrors, "; "), 2)
  end
  self:checkCancellation()

  local existingInfo = self.store.filesystem:info(self.target)
  if existingInfo then
    local existingValid =
      self.store:validate(self.target, self.profile)
    if existingValid then
      local removed, removeError =
        self.store.filesystem:removeTree(self.staging)
      requireSuccess(removed, removeError,
        "could not discard redundant staged cache")
      self.state = "reused"
      return self.target, "existing", manifest
    end

    if self.store.filesystem:info(self.quarantine) then
      error("cache quarantine path already exists", 2)
    end
    local moved, moveError =
      self.store.filesystem:rename(self.target, self.quarantine)
    requireSuccess(moved, moveError,
      "could not quarantine invalid cache")
  end

  local promoted, promoteError =
    self.store.filesystem:rename(self.staging, self.target)
  if not promoted then
    if self.store.filesystem:info(self.quarantine)
        and not self.store.filesystem:info(self.target) then
      local restored, restoreError =
        self.store.filesystem:rename(self.quarantine, self.target)
      if not restored then
        self.state = "failed"
        error("cache promotion failed: " .. tostring(promoteError)
          .. "; invalid-cache rollback also failed: "
          .. tostring(restoreError), 2)
      end
    end
    self.state = "failed"
    error("cache promotion failed: " .. tostring(promoteError), 2)
  end

  if self.store.filesystem:info(self.quarantine) then
    local removed, removeError =
      self.store.filesystem:removeTree(self.quarantine)
    if not removed then
      self.warning = "cache promoted but invalid-cache cleanup failed: "
        .. tostring(removeError or "operation failed")
    end
  end

  self.state = "committed"
  return self.target, "promoted", manifest
end

function Transaction:abort()
  if self.state == "committed" or self.state == "reused" then
    error("completed cache transaction cannot be aborted", 2)
  end
  if self.store.filesystem:info(self.staging) then
    local ok, message =
      self.store.filesystem:removeTree(self.staging)
    requireSuccess(ok, message, "could not remove cache staging directory")
  end
  self.state = "aborted"
end

function CacheStore:recover(profile)
  local filesystem = self.filesystem
  local target = CacheManifest.directory(profile, self.buildInfo)
  local targetParent = parent(target)
  local targetName = basename(target)
  local report = {
    target = target,
    status = "missing",
    actions = {},
    errors = {},
  }

  local function record(action, path)
    report.actions[#report.actions + 1] = {
      action = action,
      path = path,
    }
  end

  local function remove(path, action)
    local ok, message = filesystem:removeTree(path)
    if ok then
      record(action, path)
      return true
    end
    report.errors[#report.errors + 1] =
      "could not remove " .. path .. ": " .. tostring(message)
    return false
  end

  local parentInfo = filesystem:info(targetParent)
  if not parentInfo then
    return report
  end
  if parentInfo.type ~= "directory" then
    report.status = "blocked"
    report.errors[#report.errors + 1] =
      "cache target parent is not a directory"
    return report
  end

  local items, listError = filesystem:list(targetParent)
  if not items then
    report.status = "blocked"
    report.errors[#report.errors + 1] =
      "could not enumerate cache siblings: " .. tostring(listError)
    return report
  end

  local staging = {}
  local quarantines = {}
  local stagingPrefix = targetName .. ".staging-"
  local quarantinePrefix = targetName .. ".invalid-"
  for _, item in ipairs(items) do
    if item:sub(1, #stagingPrefix) == stagingPrefix then
      local token = item:sub(#stagingPrefix + 1)
      if validateToken(token) then
        staging[#staging + 1] = targetParent .. "/" .. item
      end
    elseif item:sub(1, #quarantinePrefix) == quarantinePrefix then
      local token = item:sub(#quarantinePrefix + 1)
      if validateToken(token) then
        quarantines[#quarantines + 1] = targetParent .. "/" .. item
      end
    end
  end
  table.sort(staging)
  table.sort(quarantines)

  local targetInfo = filesystem:info(target)
  local targetValid = false
  if targetInfo then
    targetValid = self:validate(target, profile)
  end

  if targetValid then
    report.status = "ready"
    for _, path in ipairs(staging) do
      remove(path, "removed-staging")
    end
    for _, path in ipairs(quarantines) do
      remove(path, "removed-quarantine")
    end
    return report
  end

  local validStaging = {}
  for _, path in ipairs(staging) do
    local valid = self:validate(path, profile)
    if valid then
      validStaging[#validStaging + 1] = path
    else
      remove(path, "removed-incomplete-staging")
    end
  end

  if #validStaging > 0 then
    local selected = validStaging[1]
    local recoveryQuarantine
    if targetInfo then
      for _ = 1, 32 do
        local token = self.tokenFactory()
        if not validateToken(token) then
          report.status = "blocked"
          report.errors[#report.errors + 1] =
            "cache recovery token is unsafe"
          return report
        end
        recoveryQuarantine = target .. ".invalid-" .. token
        if not filesystem:info(recoveryQuarantine) then
          break
        end
        recoveryQuarantine = nil
      end
      if not recoveryQuarantine then
        report.status = "blocked"
        report.errors[#report.errors + 1] =
          "could not allocate recovery quarantine"
        return report
      end

      local moved, moveError =
        filesystem:rename(target, recoveryQuarantine)
      if not moved then
        report.status = "blocked"
        report.errors[#report.errors + 1] =
          "could not quarantine invalid target: " .. tostring(moveError)
        return report
      end
      record("quarantined-invalid-target", recoveryQuarantine)
    end

    local promoted, promoteError = filesystem:rename(selected, target)
    if not promoted then
      if recoveryQuarantine and not filesystem:info(target) then
        local restored, restoreError =
          filesystem:rename(recoveryQuarantine, target)
        if restored then
          record("restored-invalid-target", target)
        else
          report.errors[#report.errors + 1] =
            "recovery rollback failed: " .. tostring(restoreError)
        end
      end
      report.status = "blocked"
      report.errors[#report.errors + 1] =
        "could not promote recovered staging cache: "
          .. tostring(promoteError)
      return report
    end
    record("promoted-staging", target)
    report.status = "recovered"

    for index = 2, #validStaging do
      remove(validStaging[index], "removed-redundant-staging")
    end
    for _, path in ipairs(quarantines) do
      remove(path, "removed-quarantine")
    end
    if recoveryQuarantine then
      remove(recoveryQuarantine, "removed-quarantine")
    end
    return report
  end

  if not targetInfo and #quarantines > 0 then
    local restored, restoreError =
      filesystem:rename(quarantines[1], target)
    if restored then
      record("restored-quarantine", target)
      report.status = "restored"
    else
      report.status = "blocked"
      report.errors[#report.errors + 1] =
        "could not restore quarantined target: " .. tostring(restoreError)
    end
    return report
  end

  report.status = targetInfo and "invalid" or "missing"
  return report
end

return CacheStore
