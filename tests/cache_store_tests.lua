return function(test, equal, truthy, raises)
  local CacheManifest = require("src.import.CacheManifest")
  local CacheStore = require("src.import.CacheStore")
  local MemoryFilesystem = require("tests.fixtures.MemoryFilesystem")

  local profile = {
    id = "transaction_test",
    sha1 = "abcdef0123456789abcdef0123456789abcdef01",
    cacheSchema = 1,
  }
  local buildInfo = {
    applicationId = "gen2recomp",
    applicationVersion = "transaction-test",
    importerVersion = 4,
  }

  local function newStore(filesystem, tokens)
    local index = 0
    return CacheStore.new(filesystem, {
      buildInfo = buildInfo,
      tokenFactory = function()
        index = index + 1
        return tokens and tokens[index] or ("token" .. index)
      end,
    })
  end

  test("CacheStore stages, fingerprints, and promotes payloads", function()
    local filesystem = MemoryFilesystem.new()
    local store = newStore(filesystem)
    local transaction = store:begin(profile)
    transaction:write("data/species.json", "data", "{}")
    transaction:write("text/dialogue.json", "text", "[]")

    local target, result, manifest = transaction:commit()
    equal(target, CacheManifest.directory(profile, buildInfo))
    equal(result, "promoted")
    equal(transaction.state, "committed")
    equal(manifest.fileCount, 2)
    truthy(filesystem:info(target .. "/manifest.json"))
    truthy(not filesystem:info(transaction.staging))

    local valid, errors = store:validate(target, profile)
    truthy(valid)
    equal(#errors, 0)
  end)

  test("CacheStore writes the manifest after every payload", function()
    local filesystem = MemoryFilesystem.new()
    local transaction = newStore(filesystem):begin(profile)
    transaction:write("data/one.json", "data", "one")
    transaction:write("data/two.json", "data", "two")
    transaction:commit()

    local writes = {}
    for _, event in ipairs(filesystem.events) do
      if event.operation == "write" then
        writes[#writes + 1] = event.path
      end
    end
    truthy(writes[1]:match("data/one%.json$"))
    truthy(writes[2]:match("data/two%.json$"))
    truthy(writes[3]:match("manifest%.json$"))
  end)

  test("CacheStore reuses a valid target instead of replacing it", function()
    local filesystem = MemoryFilesystem.new()
    local store = newStore(filesystem, { "first", "second" })
    local first = store:begin(profile)
    first:write("data/value.json", "data", "original")
    local target = first:commit()

    local second = store:begin(profile)
    second:write("data/value.json", "data", "replacement")
    local reusedTarget, result = second:commit()

    equal(reusedTarget, target)
    equal(result, "existing")
    equal(second.state, "reused")
    equal(filesystem:read(target .. "/data/value.json"), "original")
  end)

  test("CacheStore never damages a valid target when staging is corrupt",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem, { "first", "second" })
      local first = store:begin(profile)
      first:write("data/value.json", "data", "original")
      local target = first:commit()

      local second = store:begin(profile)
      second:write("data/value.json", "data", "replacement")
      filesystem:write(
        second.staging .. "/data/value.json",
        "corrupted after fingerprint"
      )
      raises(function() second:commit() end, "staged cache validation failed")

      local valid = store:validate(target, profile)
      truthy(valid)
      equal(filesystem:read(target .. "/data/value.json"), "original")
    end)

  test("CacheStore rolls an invalid target back when promotion fails",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem, { "replace" })
      local target = CacheManifest.directory(profile, buildInfo)
      filesystem:createDirectory(target)
      filesystem:write(target .. "/broken.txt", "old invalid cache")

      local transaction = store:begin(profile)
      transaction:write("data/value.json", "data", "replacement")
      filesystem.renameFailure = function(source)
        if source == transaction.staging then
          return "injected promotion failure"
        end
      end

      raises(function() transaction:commit() end, "promotion failed")
      truthy(filesystem:info(target))
      equal(filesystem:read(target .. "/broken.txt"), "old invalid cache")
      truthy(filesystem:info(transaction.staging))
      truthy(not filesystem:info(transaction.quarantine))
    end)

  test("CacheStore validation rejects tampering and unexpected files",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem)
      local transaction = store:begin(profile)
      transaction:write("data/value.json", "data", "original")
      local target = transaction:commit()

      filesystem:write(target .. "/data/value.json", "tampered")
      filesystem:write(target .. "/unlisted.bin", "unexpected")
      local valid, errors = store:validate(target, profile)
      truthy(not valid)
      truthy(#errors >= 2)
    end)

  test("CacheStore keeps a promoted target when quarantine cleanup fails",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = newStore(filesystem, { "cleanup" })
      local target = CacheManifest.directory(profile, buildInfo)
      filesystem:createDirectory(target)
      filesystem:write(target .. "/broken.txt", "invalid")

      local originalRemoveTree = filesystem.removeTree
      filesystem.removeTree = function(self, path)
        if path:match("%.invalid%-cleanup$") then
          return nil, "injected cleanup failure"
        end
        return originalRemoveTree(self, path)
      end

      local transaction = store:begin(profile)
      transaction:write("data/value.json", "data", "replacement")
      local promotedTarget, result = transaction:commit()

      equal(promotedTarget, target)
      equal(result, "promoted")
      equal(transaction.state, "committed")
      truthy(transaction.warning:match("cleanup failed"))
      local valid = store:validate(target, profile)
      truthy(valid)
    end)

  test("CacheStore rejects unsafe or duplicate payload writes", function()
    local transaction =
      newStore(MemoryFilesystem.new()):begin(profile)
    raises(function()
      transaction:write("../escape.json", "data", "bad")
    end, "traversal")

    transaction:write("data/value.json", "data", "good")
    raises(function()
      transaction:write("data/value.json", "data", "again")
    end, "twice")
  end)
end
