local Charmap = require("src.import.Charmap")
local Json = require("src.core.Json")

local CrystalTrainerData = {}

local PARTY_RECORD_SIZES = {
  [0] = 2,
  [1] = 6,
  [2] = 3,
  [3] = 7,
}

local function requireSymbol(profile, name)
  local symbol = profile.symbols and profile.symbols[name]
  if type(symbol) ~= "table"
      or type(symbol.offset) ~= "number"
      or type(symbol.bank) ~= "number" then
    error("trainer profile is missing symbol " .. name, 3)
  end
  return symbol
end

local function trainerId(classId, partyId)
  return ("crystal.trainer.%02d.%03d"):format(classId, partyId)
end

local function readName(rom, cursor)
  local bytes = {}
  for _ = 1, 32 do
    local value = rom:readByte(cursor)
    bytes[#bytes + 1] = string.char(value)
    cursor = cursor + 1
    if value == 0x50 then
      return Charmap.decodePlain(table.concat(bytes)), cursor
    end
  end
  error("trainer name exceeds 32 bytes", 3)
end

local function skipRecord(rom, cursor)
  local _, partyStart = readName(rom, cursor)
  local trainerType = rom:readByte(partyStart)
  local size = PARTY_RECORD_SIZES[trainerType]
  if not size then
    error("trainer party has invalid type " .. trainerType, 3)
  end
  cursor = partyStart + 1
  for _ = 1, 6 do
    if rom:readByte(cursor) == 0xff then return cursor + 1 end
    rom:assertRange(cursor, size)
    cursor = cursor + size
  end
  error("trainer party exceeds six members", 3)
end

local function readParty(rom, cursor, classId, partyId)
  local name
  name, cursor = readName(rom, cursor)
  local trainerType = rom:readByte(cursor)
  local size = PARTY_RECORD_SIZES[trainerType]
  if not size then
    error("trainer party has invalid type " .. trainerType, 3)
  end
  cursor = cursor + 1
  local party = Json.array({})
  while rom:readByte(cursor) ~= 0xff do
    if #party >= 6 then
      error("trainer party exceeds six members", 3)
    end
    rom:assertRange(cursor, size)
    local level = rom:readByte(cursor)
    local speciesNumber = rom:readByte(cursor + 1)
    if level < 1 or level > 100
        or speciesNumber < 1 or speciesNumber > 251 then
      error("trainer party has invalid Pokemon data", 3)
    end
    local member = {
      level = level,
      speciesNumber = speciesNumber,
    }
    local moveOffset
    if trainerType == 2 or trainerType == 3 then
      member.heldItemId = rom:readByte(cursor + 2)
    end
    if trainerType == 1 then
      moveOffset = cursor + 2
    elseif trainerType == 3 then
      moveOffset = cursor + 3
    end
    if moveOffset then
      local moves = Json.array({})
      for index = 0, 3 do
        local move = rom:readByte(moveOffset + index)
        if move ~= 0 then moves[#moves + 1] = move end
      end
      member.moveNumbers = moves
    end
    party[#party + 1] = member
    cursor = cursor + size
  end
  if #party == 0 then error("trainer party is empty", 3) end
  return {
    id = trainerId(classId, partyId),
    name = name,
    classId = classId,
    partyId = partyId,
    trainerType = trainerType,
    aiProfileId = "battle.ai.basic",
    party = party,
  }
end

local function readTrainer(rom, tableStart, classId, partyId)
  if classId < 1 or classId > 67 or partyId < 1 then
    error("trainer reference is out of range", 3)
  end
  local groupAddress =
    rom:readWord(tableStart.offset + (classId - 1) * 2)
  local cursor = rom:offset(tableStart.bank, groupAddress, 1)
  for _ = 2, partyId do cursor = skipRecord(rom, cursor) end
  return readParty(rom, cursor, classId, partyId)
end

function CrystalTrainerData.extract(rom, profile, references)
  if type(references) ~= "table" then
    error("trainer extraction requires references", 2)
  end
  local tableStart = requireSymbol(profile, "TrainerGroups")
  local unique = {}
  for _, reference in ipairs(references) do
    local id = trainerId(reference.classId, reference.partyId)
    unique[id] = reference
  end
  local ids = {}
  for id in pairs(unique) do ids[#ids + 1] = id end
  table.sort(ids)

  local records = Json.array({})
  for _, id in ipairs(ids) do
    local reference = unique[id]
    records[#records + 1] = readTrainer(
      rom,
      tableStart,
      reference.classId,
      reference.partyId
    )
  end
  return {
    schema = 1,
    records = records,
  }
end

CrystalTrainerData.id = trainerId

return CrystalTrainerData
