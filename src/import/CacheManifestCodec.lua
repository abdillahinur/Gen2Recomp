local CacheManifest = require("src.import.CacheManifest")
local Json = require("src.core.Json")

local CacheManifestCodec = {}

function CacheManifestCodec.encode(manifest)
  local valid, errors = CacheManifest.validate(manifest)
  if not valid then
    error("cannot encode invalid cache manifest: "
      .. table.concat(errors, "; "), 2)
  end
  return Json.encode(manifest) .. "\n"
end

function CacheManifestCodec.decode(source)
  local manifest = Json.decode(source)
  local valid, errors = CacheManifest.validate(manifest)
  if not valid then
    error("invalid cache manifest: " .. table.concat(errors, "; "), 2)
  end
  return manifest
end

return CacheManifestCodec
