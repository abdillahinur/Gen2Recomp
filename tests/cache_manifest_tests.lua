return function(test, equal, truthy, raises)
  local CacheManifest = require("src.import.CacheManifest")

  local profile = {
    id = "synthetic_profile",
    sha1 = "0123456789abcdef0123456789abcdef01234567",
    cacheSchema = 3,
  }
  local buildInfo = {
    applicationId = "gen2recomp",
    applicationVersion = "test-build",
    importerVersion = 7,
  }

  local function files()
    return {
      {
        path = "text/dialogue.json",
        kind = "text",
        size = 20,
        sha1 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      },
      {
        path = "data/species.json",
        kind = "data",
        size = 10,
        sha1 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      },
    }
  end

  test("CacheManifest creates a sorted, summarized inventory", function()
    local manifest = CacheManifest.new(profile, files(), buildInfo)

    equal(manifest.format, "gen2recomp-cache")
    equal(manifest.formatVersion, 1)
    equal(manifest.state, "complete")
    equal(manifest.owner.profileId, profile.id)
    equal(manifest.owner.romSha1, profile.sha1)
    equal(manifest.owner.cacheSchema, 3)
    equal(manifest.owner.importerVersion, 7)
    equal(manifest.producer.applicationVersion, "test-build")
    equal(manifest.files[1].path, "data/species.json")
    equal(manifest.files[1].sha1,
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    equal(manifest.files[2].path, "text/dialogue.json")
    equal(manifest.fileCount, 2)
    equal(manifest.totalBytes, 30)

    local valid, errors = CacheManifest.validate(manifest)
    truthy(valid)
    equal(#errors, 0)
  end)

  test("CacheManifest derives deterministic ownership directories", function()
    equal(
      CacheManifest.directory(profile, buildInfo),
      "cache/synthetic_profile/"
        .. "0123456789abcdef0123456789abcdef01234567/"
        .. "schema-3/importer-7"
    )
  end)

  test("CacheManifest matches every ownership component", function()
    local manifest = CacheManifest.new(profile, files(), buildInfo)
    local matches = CacheManifest.matches(manifest, profile, buildInfo)
    truthy(matches)

    local newerApp = {
      applicationId = "gen2recomp",
      applicationVersion = "newer-app",
      importerVersion = 7,
    }
    local newerAppMatches =
      CacheManifest.matches(manifest, profile, newerApp)
    truthy(newerAppMatches)

    local changedImporter = {
      applicationId = "gen2recomp",
      applicationVersion = "newer-app",
      importerVersion = 8,
    }
    local otherMatches, errors =
      CacheManifest.matches(manifest, profile, changedImporter)
    truthy(not otherMatches)
    truthy(errors[1]:match("importerVersion"))
  end)

  test("CacheManifest rejects traversal and private-source file types",
    function()
      local invalidFiles = files()
      invalidFiles[1].path = "../source.gbc"
      raises(function()
        CacheManifest.new(profile, invalidFiles, buildInfo)
      end, "traversal")

      invalidFiles = files()
      invalidFiles[1].path = "source.gbc"
      raises(function()
        CacheManifest.new(profile, invalidFiles, buildInfo)
      end, "forbidden")
    end)

  test("CacheManifest rejects duplicate inventory paths", function()
    local invalidFiles = files()
    invalidFiles[2].path = invalidFiles[1].path
    raises(function()
      CacheManifest.new(profile, invalidFiles, buildInfo)
    end, "duplicate")
  end)

  test("CacheManifest validation detects tampered summaries and state",
    function()
      local manifest = CacheManifest.new(profile, files(), buildInfo)
      manifest.totalBytes = 31
      manifest.state = "building"

      local valid, errors = CacheManifest.validate(manifest)
      truthy(not valid)
      truthy(#errors >= 2)
    end)

  test("CacheManifest rejects unsafe profile ownership", function()
    raises(function()
      CacheManifest.new({
        id = "../escape",
        sha1 = profile.sha1,
        cacheSchema = 1,
      }, {}, buildInfo)
    end, "not safe")

    raises(function()
      CacheManifest.new({
        id = "safe",
        sha1 = "not-a-hash",
        cacheSchema = 1,
      }, {}, buildInfo)
    end, "SHA%-1")
  end)
end
