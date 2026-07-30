return function(test, equal, truthy, raises)
  local CacheManifest = require("src.import.CacheManifest")
  local Codec = require("src.import.CacheManifestCodec")

  local profile = {
    id = "codec_test",
    sha1 = "1234567890abcdef1234567890abcdef12345678",
    cacheSchema = 1,
  }
  local buildInfo = {
    applicationId = "gen2recomp",
    applicationVersion = "codec-test",
    importerVersion = 2,
  }

  test("CacheManifestCodec round-trips deterministic JSON", function()
    local manifest = CacheManifest.new(profile, {
      {
        path = "data/example.json",
        kind = "data",
        size = 3,
        sha1 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      },
    }, buildInfo)
    local encoded = Codec.encode(manifest)
    local decoded = Codec.decode(encoded)

    equal(encoded:sub(-1), "\n")
    equal(decoded.owner.profileId, "codec_test")
    equal(decoded.files[1].path, "data/example.json")
    local matches = CacheManifest.matches(decoded, profile, buildInfo)
    truthy(matches)
    equal(Codec.encode(decoded), encoded)
  end)

  test("CacheManifestCodec preserves an empty file array", function()
    local encoded = Codec.encode(
      CacheManifest.new(profile, {}, buildInfo)
    )
    truthy(encoded:match('"files":%[%]'))
    local decoded = Codec.decode(encoded)
    equal(#decoded.files, 0)
  end)

  test("CacheManifestCodec rejects invalid manifests without execution",
    function()
      raises(function()
        Codec.decode('{"format":"wrong"}')
      end, "invalid cache manifest")
      raises(function()
        Codec.decode('return os.execute("anything")')
      end, "JSON decode error")
    end)
end
