local Provenance = {}

local SOURCES = {
  crystal = {
    id = "pret/pokecrystal",
    repository = "https://github.com/pret/pokecrystal",
    revision = "3438c7003a57fa2987fcb223d14b660761b33c64",
  },
}

local function copyArray(values)
  local result = {}
  for index, value in ipairs(values or {}) do
    result[index] = value
  end
  return result
end

function Provenance.source(game)
  return SOURCES[game]
end

function Provenance.citation(game, path, labels, notes)
  local source = SOURCES[game]
  if not source then
    error("no pinned behavior reference for game: " .. tostring(game), 2)
  end
  return {
    source = source.id,
    revision = source.revision,
    path = path,
    labels = copyArray(labels),
    notes = notes,
  }
end

return Provenance
