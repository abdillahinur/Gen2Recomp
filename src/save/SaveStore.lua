local NativeSaveCodec = require("src.save.NativeSaveCodec")
local RtcPersistence = require("src.save.RtcPersistence")

local SaveStore = {}
SaveStore.__index = SaveStore

local function paths(profileId)
  local base = "saves/" .. profileId
  return base .. ".json", base .. ".backup.json",
    base .. ".staging.json"
end

function SaveStore.new(filesystem)
  return setmetatable({ filesystem = filesystem }, SaveStore)
end

function SaveStore:save(profileId, snapshot, savedAt)
  local target, backup, staging = paths(profileId)
  self.filesystem:createDirectory("saves")
  self.filesystem:removeTree(staging)
  local ok, message = self.filesystem:write(
    staging,
    NativeSaveCodec.encode(profileId, snapshot, savedAt)
  )
  if not ok then return nil, message end
  self.filesystem:removeTree(backup)
  if self.filesystem:info(target) then
    ok, message = self.filesystem:rename(target, backup)
    if not ok then
      self.filesystem:removeTree(staging)
      return nil, message
    end
  end
  ok, message = self.filesystem:rename(staging, target)
  if not ok then
    if self.filesystem:info(backup)
        and not self.filesystem:info(target) then
      self.filesystem:rename(backup, target)
    end
    return nil, message
  end
  return true
end

function SaveStore:_loadPath(path, profileId, now)
  local source = self.filesystem:read(path)
  if not source then return nil end
  local ok, snapshot, savedAt = pcall(
    NativeSaveCodec.decode, source, profileId)
  if not ok then return nil, snapshot end
  return RtcPersistence.reconcile(snapshot, savedAt, now)
end

function SaveStore:load(profileId, now)
  local target, backup = paths(profileId)
  local snapshot, rtcOrError =
    self:_loadPath(target, profileId, now)
  if snapshot then return snapshot, rtcOrError, "primary" end
  local backupSnapshot, backupRtc =
    self:_loadPath(backup, profileId, now)
  if backupSnapshot then
    return backupSnapshot, backupRtc, "backup"
  end
  return nil, rtcOrError or backupRtc or "save_not_found"
end

return SaveStore
