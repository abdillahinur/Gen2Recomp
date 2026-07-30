local profileModules = {
  "manifests.crystal_us_10",
}

local profiles = {}
local byId = {}
local bySha1 = {}

for _, moduleName in ipairs(profileModules) do
  local profile = require(moduleName)
  assert(type(profile.id) == "string", moduleName .. " is missing id")
  assert(type(profile.sha1) == "string", moduleName .. " is missing sha1")
  local normalizedSha1 = profile.sha1:lower()
  assert(not byId[profile.id], "duplicate profile id: " .. profile.id)
  assert(not bySha1[normalizedSha1],
    "duplicate profile hash: " .. profile.sha1)

  profiles[#profiles + 1] = profile
  byId[profile.id] = profile
  bySha1[normalizedSha1] = profile
end

local Profiles = {}

function Profiles.all()
  local result = {}
  for index, profile in ipairs(profiles) do
    result[index] = profile
  end
  return result
end

function Profiles.get(id)
  return byId[id]
end

function Profiles.identifySha1(sha1)
  if type(sha1) ~= "string" then
    return nil
  end
  return bySha1[sha1:lower()]
end

return Profiles
