return function(test, equal, truthy, raises)
  local CacheManifest = require("src.import.CacheManifest")
  local CacheStore = require("src.import.CacheStore")
  local CancellationToken = require("src.core.CancellationToken")
  local MemoryFilesystem = require("tests.fixtures.MemoryFilesystem")

  local profile = {
    id = "recovery_test",
    sha1 = "00112233445566778899aabbccddeeff00112233",
    cacheSchema = 2,
  }
  local buildInfo = {
    applicationId = "gen2recomp",
    applicationVersion = "recovery-test",
    importerVersion = 5,
  }

  local function newStore(filesystem, tokens)
    local index = 0
    return CacheStore.new(filesystem, {
      buildInfo = buildInfo,
      tokenFactory = function()
        index = index + 1
        return tokens[index] or ("fallback" .. index)
      end,
    })
  end

  test("Cancelled cache transactions remove their staging directory",
    function()
      local filesystem = MemoryFilesystem.new()
      local token = CancellationToken.new()
      local transaction = newStore(filesystem, { "cancel" })
        :begin(profile, { cancellationToken = token })
      transaction:write("data/value.json", "data", "value")
      token:cancel("user request")

      raises(function() transaction:commit() end, "user request")
      equal(transaction.state, "aborted")
      truthy(not filesystem:info(transaction.staging))
    end)

  test("Cancellation cannot damage a valid existing cache", function()
    local filesystem = MemoryFilesystem.new()
    local store = newStore(filesystem, { "first", "cancelled" })
    local first = store:begin(profile)
    first:write("data/value.json", "data", "original")
    local target = first:commit()

    local token = CancellationToken.new()
    local second = store:begin(profile, { cancellationToken = token })
    second:write("data/value.json", "data", "replacement")
    token:cancel("stop")
    raises(function() second:commit() end, "cancelled")

    local valid = store:validate(target, profile)
    truthy(valid)
    equal(filesystem:read(target .. "/data/value.json"), "original")
  end)

  test("Recovery promotes a complete abandoned staging cache", function()
    local filesystem = MemoryFilesystem.new()
    local store = newStore(filesystem, { "abandoned" })
    local transaction = store:begin(profile)
    transaction:write("data/value.json", "data", "recovered")
    filesystem.renameFailure = function(source)
      if source == transaction.staging then
        return "simulated interruption"
      end
    end
    raises(function() transaction:commit() end, "promotion failed")
    filesystem.renameFailure = nil

    local report = store:recover(profile)
    local target = CacheManifest.directory(profile, buildInfo)
    equal(report.status, "recovered")
    equal(filesystem:read(target .. "/data/value.json"), "recovered")
    local valid = store:validate(target, profile)
    truthy(valid)
  end)

  test("Recovery removes incomplete staging beside a valid target",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem, { "valid", "incomplete" })
      local validTransaction = store:begin(profile)
      validTransaction:write("data/value.json", "data", "valid")
      local target = validTransaction:commit()

      local incomplete = store:begin(profile)
      incomplete:write("data/partial.json", "data", "partial")
      local report = store:recover(profile)

      equal(report.status, "ready")
      truthy(not filesystem:info(incomplete.staging))
      truthy(store:validate(target, profile))
    end)

  test("Recovery restores a quarantined directory when no target survives",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem, { "old" })
      local target = CacheManifest.directory(profile, buildInfo)
      local quarantine = target .. ".invalid-old"
      filesystem:createDirectory(quarantine)
      filesystem:write(quarantine .. "/diagnostic.txt", "preserve")

      local report = store:recover(profile)
      equal(report.status, "restored")
      equal(filesystem:read(target .. "/diagnostic.txt"), "preserve")
      truthy(not filesystem:info(quarantine))
    end)

  test("Recovery never replaces a valid target with abandoned staging",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem, { "valid", "abandoned" })
      local first = store:begin(profile)
      first:write("data/value.json", "data", "original")
      local target = first:commit()

      local abandoned = store:begin(profile)
      abandoned:write("data/value.json", "data", "other")
      local report = store:recover(profile)

      equal(report.status, "ready")
      equal(filesystem:read(target .. "/data/value.json"), "original")
      truthy(not filesystem:info(abandoned.staging))
    end)
end
