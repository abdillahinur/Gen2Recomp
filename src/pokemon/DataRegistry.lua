local ItemRecord = require("src.pokemon.ItemRecord")
local MoveRecord = require("src.pokemon.MoveRecord")
local SpeciesRecord = require("src.pokemon.SpeciesRecord")
local TrainerRecord = require("src.pokemon.TrainerRecord")

local DataRegistry = {}
DataRegistry.__index = DataRegistry

local NORMALIZERS = {
  species = SpeciesRecord,
  moves = MoveRecord,
  items = ItemRecord,
  trainers = TrainerRecord,
}

local function addAll(target, values, normalizer, kind)
  for _, source in ipairs(values or {}) do
    local record = normalizer.normalize(source)
    if target[record.id] then
      error("data registry: duplicate " .. kind .. " id " .. record.id, 3)
    end
    target[record.id] = record
  end
end

function DataRegistry.new(data)
  data = data or {}
  local self = setmetatable({
    species = {},
    moves = {},
    items = {},
    trainers = {},
  }, DataRegistry)
  for field, normalizer in pairs(NORMALIZERS) do
    addAll(self[field], data[field], normalizer, field)
  end
  return self
end

function DataRegistry:get(kind, id)
  local records = self[kind]
  if not records then
    error("data registry: unknown record kind " .. tostring(kind), 2)
  end
  local record = records[id]
  if not record then
    error(("data registry: unknown %s id %s")
      :format(kind, tostring(id)), 2)
  end
  return record
end

return DataRegistry
