local Json = require("src.core.Json")
local Sha1 = require("src.import.Sha1")

local NativeSaveCodec = {}

local FORMAT = "gen2recomp.native-save"
local SCHEMA = 1

function NativeSaveCodec.encode(profileId, snapshot, savedAt)
  local payload = Json.encode(snapshot)
  return Json.encode({
    format = FORMAT,
    schema = SCHEMA,
    profileId = profileId,
    savedAt = savedAt,
    payloadSha1 = Sha1.hex(payload),
    payload = snapshot,
  })
end

function NativeSaveCodec.decode(source, expectedProfileId)
  local envelope = Json.decode(source)
  if envelope.format ~= FORMAT or envelope.schema ~= SCHEMA then
    error("native save: unsupported format or schema", 2)
  end
  if envelope.profileId ~= expectedProfileId then
    error("native save: ROM profile mismatch", 2)
  end
  if type(envelope.savedAt) ~= "number"
      or envelope.savedAt % 1 ~= 0 or envelope.savedAt < 0 then
    error("native save: savedAt is invalid", 2)
  end
  if type(envelope.payload) ~= "table"
      or Sha1.hex(Json.encode(envelope.payload))
        ~= envelope.payloadSha1 then
    error("native save: payload checksum mismatch", 2)
  end
  return envelope.payload, envelope.savedAt
end

NativeSaveCodec.FORMAT = FORMAT
NativeSaveCodec.SCHEMA = SCHEMA

return NativeSaveCodec
