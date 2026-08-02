local CgbPalette = require("src.import.CgbPalette")
local CrystalEncounterData = require("src.import.CrystalEncounterData")
local CrystalTrainerData = require("src.import.CrystalTrainerData")
local CrystalTileset = require("src.import.CrystalTileset")
local Json = require("src.core.Json")
local TileDecoder = require("src.import.TileDecoder")

local CrystalWorldData = {}

local MAP_HEADER_SIZE = 9
local MAP_ATTRIBUTES_SIZE = 12
local CONNECTION_SIZE = 12
local WARP_EVENT_SIZE = 5
local COORD_EVENT_SIZE = 8
local BG_EVENT_SIZE = 5
local OBJECT_EVENT_SIZE = 13
local SPRITE_HEADER_SIZE = 6
local ROOF_TILE_COUNT = 9
local ROOF_COUNT = 5
local LAST_OVERWORLD_SPRITE = 0x66
local FIRST_POKEMON_SPRITE = 0x80
local LAST_POKEMON_SPRITE = 0xa2
local FIRST_DAY_CARE_SPRITE = 0xe0
local LAST_DAY_CARE_SPRITE = 0xe1
local VARIABLE_SPRITE_BASE = 0xf0
local OBJECT_TYPE_TRAINER = 2

local DIRECTIONS = {
  { name = "north", mask = 0x08 },
  { name = "south", mask = 0x04 },
  { name = "west", mask = 0x02 },
  { name = "east", mask = 0x01 },
}

local SPRITE_NAMES = {
  [1] = "chris",
  [4] = "rival",
  [41] = "teacher",
  [58] = "fisher",
  [96] = "kris",
}

local TILESET_NAMES = {
  [1] = "johto",
  [5] = "house",
  [6] = "players_house",
  [7] = "pokecenter",
  [8] = "gate",
  [10] = "lab",
  [11] = "facility",
  [12] = "mart",
  [15] = "elite_four_room",
  [16] = "traditional_house",
  [20] = "players_room",
}

function CrystalWorldData.tilesetName(id)
  return TILESET_NAMES[id]
end

local function requireSymbol(profile, name)
  local symbol = profile.symbols and profile.symbols[name]
  if type(symbol) ~= "table"
      or type(symbol.offset) ~= "number"
      or type(symbol.bank) ~= "number"
      or type(symbol.address) ~= "number" then
    error("world profile is missing symbol " .. name, 3)
  end
  return symbol
end

local function hasMask(value, mask)
  return math.floor(value / mask) % 2 == 1
end

local function signedByte(value)
  return value >= 0x80 and value - 0x100 or value
end

local function mapId(group, map)
  return ("%d:%d"):format(group, map)
end

local function spriteKind(id)
  if id == 0 then
    return "none"
  elseif id <= LAST_OVERWORLD_SPRITE then
    return "graphic"
  elseif id >= FIRST_POKEMON_SPRITE
      and id <= LAST_POKEMON_SPRITE then
    return "pokemon"
  elseif id >= FIRST_DAY_CARE_SPRITE
      and id <= LAST_DAY_CARE_SPRITE then
    return "day_care"
  elseif id >= VARIABLE_SPRITE_BASE then
    return "variable"
  end
  return "special"
end

local function initialFacing(movementId)
  return movementId == 7 and "up"
    or movementId == 8 and "left"
    or movementId == 9 and "right"
    or "down"
end

local function findGroup(groups, id)
  for _, group in ipairs(groups) do
    if group.id == id then
      return group
    end
  end
end

local function findMap(group, id)
  if not group then
    return nil
  end
  for _, map in ipairs(group.maps) do
    if map.id == id then
      return map
    end
  end
end

local function byteList(rom, offset, count)
  local values = Json.array({})
  for index = 0, count - 1 do
    values[#values + 1] = rom:readByte(offset + index)
  end
  return values
end

local function readEventCount(rom, cursor, label)
  local count = rom:readByte(cursor)
  if count > 64 then
    error(("Crystal %s count %d is implausible"):format(label, count), 3)
  end
  return count, cursor + 1
end

local function decodeEvents(rom, bank, address)
  local cursor = rom:offset(bank, address, 2)
  cursor = cursor + 2

  local warps = Json.array({})
  local warpCount
  warpCount, cursor = readEventCount(rom, cursor, "warp event")
  for index = 1, warpCount do
    rom:assertRange(cursor, WARP_EVENT_SIZE)
    local targetGroup = rom:readByte(cursor + 3)
    local targetMap = rom:readByte(cursor + 4)
    warps[index] = {
      id = index,
      y = rom:readByte(cursor),
      x = rom:readByte(cursor + 1),
      targetWarp = rom:readByte(cursor + 2),
      targetMapId = mapId(targetGroup, targetMap),
      targetGroup = targetGroup,
      targetMap = targetMap,
    }
    cursor = cursor + WARP_EVENT_SIZE
  end

  local coordEvents = Json.array({})
  local coordCount
  coordCount, cursor = readEventCount(rom, cursor, "coordinate event")
  for index = 1, coordCount do
    rom:assertRange(cursor, COORD_EVENT_SIZE)
    coordEvents[index] = {
      id = index,
      sceneId = rom:readByte(cursor),
      y = rom:readByte(cursor + 1),
      x = rom:readByte(cursor + 2),
    }
    cursor = cursor + COORD_EVENT_SIZE
  end

  local bgEvents = Json.array({})
  local bgCount
  bgCount, cursor = readEventCount(rom, cursor, "background event")
  for index = 1, bgCount do
    rom:assertRange(cursor, BG_EVENT_SIZE)
    bgEvents[index] = {
      id = index,
      y = rom:readByte(cursor),
      x = rom:readByte(cursor + 1),
      kind = rom:readByte(cursor + 2),
    }
    cursor = cursor + BG_EVENT_SIZE
  end

  local objects = Json.array({})
  local objectCount
  objectCount, cursor = readEventCount(rom, cursor, "object event")
  for index = 1, objectCount do
    rom:assertRange(cursor, OBJECT_EVENT_SIZE)
    local radius = rom:readByte(cursor + 4)
    local typePalette = rom:readByte(cursor + 7)
    local eventFlag = rom:readWord(cursor + 11)
    local spriteId = rom:readByte(cursor)
    local movementId = rom:readByte(cursor + 3)
    local objectType = typePalette % 0x10
    local trainer
    if objectType == OBJECT_TYPE_TRAINER then
      local trainerAddress = rom:readWord(cursor + 9)
      local trainerOffset = rom:offset(bank, trainerAddress, 12)
      local defeatFlagId = rom:readWord(trainerOffset)
      local classId = rom:readByte(trainerOffset + 2)
      local partyId = rom:readByte(trainerOffset + 3)
      trainer = {
        id = CrystalTrainerData.id(classId, partyId),
        classId = classId,
        partyId = partyId,
        defeatFlagId = defeatFlagId,
      }
    end
    objects[index] = {
      id = index,
      spriteId = spriteId,
      spriteKind = spriteKind(spriteId),
      y = rom:readByte(cursor + 1) - 4,
      x = rom:readByte(cursor + 2) - 4,
      movementId = movementId,
      facing = initialFacing(movementId),
      radiusX = radius % 0x10,
      radiusY = math.floor(radius / 0x10),
      hourStart = signedByte(rom:readByte(cursor + 5)),
      hourEnd = signedByte(rom:readByte(cursor + 6)),
      paletteId = math.floor(typePalette / 0x10),
      objectType = objectType,
      sightRange = rom:readByte(cursor + 8),
      eventFlagId = eventFlag == 0xffff and -1 or eventFlag,
      trainer = trainer,
    }
    cursor = cursor + OBJECT_EVENT_SIZE
  end

  return {
    warps = warps,
    coordEvents = coordEvents,
    bgEvents = bgEvents,
    objects = objects,
  }
end

local function decodeConnections(rom, offset, mask)
  local connections = Json.array({})
  local cursor = offset
  for _, direction in ipairs(DIRECTIONS) do
    if hasMask(mask, direction.mask) then
      rom:assertRange(cursor, CONNECTION_SIZE)
      local group = rom:readByte(cursor)
      local map = rom:readByte(cursor + 1)
      connections[#connections + 1] = {
        direction = direction.name,
        targetMapId = mapId(group, map),
        targetGroup = group,
        targetMap = map,
        stripLength = rom:readByte(cursor + 6),
        targetWidthBlocks = rom:readByte(cursor + 7),
        targetY = signedByte(rom:readByte(cursor + 8)),
        targetX = signedByte(rom:readByte(cursor + 9)),
      }
      cursor = cursor + CONNECTION_SIZE
    end
  end
  return connections
end

local function decodeMap(rom, header, groupId, mapIndex, name)
  local attributesOffset = rom:offset(
    header.attributesBank,
    header.attributesAddress,
    MAP_ATTRIBUTES_SIZE
  )
  local borderBlock = rom:readByte(attributesOffset)
  local height = rom:readByte(attributesOffset + 1)
  local width = rom:readByte(attributesOffset + 2)
  if width < 1 or height < 1 or width > 64 or height > 64 then
    error(("Crystal map %s has invalid dimensions %dx%d")
      :format(name, width, height), 3)
  end

  local blocksBank = rom:readByte(attributesOffset + 3)
  local blocksAddress = rom:readWord(attributesOffset + 4)
  local eventsBank = rom:readByte(attributesOffset + 6)
  local eventsAddress = rom:readWord(attributesOffset + 9)
  local connectionMask = rom:readByte(attributesOffset + 11)
  local blockCount = width * height
  local blocksOffset = rom:offset(blocksBank, blocksAddress, blockCount)

  local events = decodeEvents(rom, eventsBank, eventsAddress)
  return {
    id = mapId(groupId, mapIndex),
    name = name,
    group = groupId,
    map = mapIndex,
    widthBlocks = width,
    heightBlocks = height,
    widthTiles = width * 4,
    heightTiles = height * 4,
    widthCells = width * 2,
    heightCells = height * 2,
    borderBlock = borderBlock,
    tilesetId = header.tilesetId,
    environmentId = header.environmentId,
    landmarkId = header.landmarkId,
    musicId = header.musicId,
    paletteModeId = header.paletteModeId,
    fishingGroupId = header.fishingGroupId,
    blocks = byteList(rom, blocksOffset, blockCount),
    connections = decodeConnections(
      rom,
      attributesOffset + MAP_ATTRIBUTES_SIZE,
      connectionMask
    ),
    warps = events.warps,
    coordEvents = events.coordEvents,
    bgEvents = events.bgEvents,
    objects = events.objects,
  }
end

local function decodeHeader(rom, offset, groupId, mapIndex, name)
  rom:assertRange(offset, MAP_HEADER_SIZE)
  local packed = rom:readByte(offset + 7)
  return {
    id = mapId(groupId, mapIndex),
    name = name,
    group = groupId,
    map = mapIndex,
    attributesBank = rom:readByte(offset),
    tilesetId = rom:readByte(offset + 1),
    environmentId = rom:readByte(offset + 2),
    attributesAddress = rom:readWord(offset + 3),
    landmarkId = rom:readByte(offset + 5),
    musicId = rom:readByte(offset + 6),
    phoneServiceBlocked = math.floor(packed / 0x10) ~= 0,
    paletteModeId = packed % 0x10,
    fishingGroupId = rom:readByte(offset + 8),
  }
end

local function decodeGroup(rom, profile, group)
  local pointers = requireSymbol(profile, "MapGroupPointers")
  local pointerOffset = pointers.offset + (group.id - 1) * 2
  local groupAddress = rom:readWord(pointerOffset)
  local groupOffset = rom:offset(
    pointers.bank,
    groupAddress,
    #group.maps * MAP_HEADER_SIZE
  )

  local extract = {}
  for _, index in ipairs(group.extractMapIndexes or {}) do
    extract[index] = true
  end

  local headers = Json.array({})
  local maps = Json.array({})
  for index, name in ipairs(group.maps) do
    local header = decodeHeader(
      rom,
      groupOffset + (index - 1) * MAP_HEADER_SIZE,
      group.id,
      index,
      name
    )
    header.extracted = extract[index] == true
    headers[#headers + 1] = header
    if extract[index] then
      maps[#maps + 1] =
        decodeMap(rom, header, group.id, index, name)
    end
  end

  return {
    id = group.id,
    name = group.name,
    headers = headers,
    maps = maps,
  }
end

local function directionList(index)
  local names = Json.array({})
  local values = {
    Json.array({ "right" }),
    Json.array({ "left" }),
    Json.array({ "down" }),
    Json.array({ "up" }),
    Json.array({ "up", "right" }),
    Json.array({ "up", "left" }),
    Json.array({ "down", "right" }),
    Json.array({ "down", "left" }),
  }
  for _, value in ipairs(values[index + 1]) do
    names[#names + 1] = value
  end
  return names
end

local function decodeCollisionPermissions(rom, profile)
  local start = requireSymbol(profile, "CollisionPermissionTable")
  local permissions = Json.array({})
  for id = 0, 255 do
    local raw = rom:readByte(start.offset + id)
    local terrain = raw % 0x10
    local record = {
      id = id,
      raw = raw,
      terrain = terrain == 0 and "land"
        or terrain == 1 and "water"
        or "wall",
      talk = raw >= 0x10,
      directional = false,
      directions = Json.array({}),
    }
    local high = math.floor(id / 0x10) * 0x10
    if high == 0xa0 then
      record.directional = true
      record.directionKind = "ledge"
      record.directions = directionList(id % 8)
    elseif high == 0xb0 or high == 0xc0 then
      record.directional = true
      record.directionKind =
        high == 0xb0 and "wall" or "buoy"
      record.directions = directionList(id % 8)
    end
    permissions[#permissions + 1] = record
  end
  return permissions
end

local function decodeObjectPalettes(rom, profile)
  local start = requireSymbol(profile, "MapObjectPals")
  local finish = requireSymbol(profile, "RoofPals")
  local data = rom:readString(start.offset, finish.offset - start.offset)
  if #data ~= 4 * 8 * 8 then
    error("Crystal object palette table has an invalid length", 3)
  end

  local sets = {}
  local names = { "morning", "day", "night", "dark" }
  local offset = 1
  for _, name in ipairs(names) do
    local palettes = Json.array({})
    for id = 0, 7 do
      local palette = CgbPalette.decodePalette(data, offset)
      palette.id = id
      palettes[#palettes + 1] = palette
      offset = offset + 8
    end
    sets[name] = palettes
  end
  return sets
end

local function decodeRoofs(rom, profile, groupIds)
  local groupTable = requireSymbol(profile, "MapGroupRoofs")
  local roofsStart = requireSymbol(profile, "Roofs")
  local palettesStart = requireSymbol(profile, "RoofPals")
  local palettesEnd = requireSymbol(profile, "DiplomaPalettes")
  local roofBytes = ROOF_COUNT * ROOF_TILE_COUNT * 16
  local allRoofData = rom:readString(roofsStart.offset, roofBytes)
  local paletteData = rom:readString(
    palettesStart.offset,
    palettesEnd.offset - palettesStart.offset
  )
  if #paletteData ~= 27 * 8 then
    error("Crystal roof palette table has an invalid length", 3)
  end

  local groups = Json.array({})
  for _, groupId in ipairs(groupIds) do
    local roofId = rom:readByte(groupTable.offset + groupId)
    local record = {
      group = groupId,
      roofId = roofId == 0xff and -1 or roofId,
      palettes = {},
    }
    if record.roofId >= 0 then
      local start = record.roofId * ROOF_TILE_COUNT * 16 + 1
      local raw = allRoofData:sub(start, start + ROOF_TILE_COUNT * 16 - 1)
      record.tiles = TileDecoder.decode2bpp(raw)
    else
      record.tiles = Json.array({})
    end

    local paletteOffset = groupId * 8 + 1
    record.palettes.morningDay = CgbPalette.decodePalette(
      paletteData,
      paletteOffset,
      2
    )
    record.palettes.night = CgbPalette.decodePalette(
      paletteData,
      paletteOffset + 4,
      2
    )
    groups[#groups + 1] = record
  end
  return groups
end

local function decodeSprites(rom, profile, spriteIds)
  local tableStart = requireSymbol(profile, "OverworldSprites")
  local sprites = Json.array({})
  local sorted = {}
  for id in pairs(spriteIds) do
    sorted[#sorted + 1] = id
  end
  table.sort(sorted)

  for _, id in ipairs(sorted) do
    if id < 0 or id > 255 then
      error("Crystal overworld sprite id is out of range", 3)
    end
    if id >= 1 and id <= LAST_OVERWORLD_SPRITE then
      local offset = tableStart.offset + (id - 1) * SPRITE_HEADER_SIZE
      local address = rom:readWord(offset)
      local byteCount = rom:readByte(offset + 2)
      local tileCount = byteCount / 16
      local bank = rom:readByte(offset + 3)
      local kind = rom:readByte(offset + 4)
      local paletteId = rom:readByte(offset + 5)
      if tileCount ~= 4 and tileCount ~= 12 then
        error(("Crystal sprite %d has invalid byte count %d")
          :format(id, byteCount), 3)
      end
      local data = rom:string(bank, address, tileCount * 16)
      sprites[#sprites + 1] = {
        id = id,
        name = SPRITE_NAMES[id] or ("sprite_%d"):format(id),
        tileCount = tileCount,
        kind = kind,
        defaultPaletteId = paletteId,
        tiles = TileDecoder.decode2bpp(data),
      }
    end
  end
  return sprites
end

function CrystalWorldData.extract(rom, profile)
  local worldProfile = profile.world
  if type(worldProfile) ~= "table"
      or type(worldProfile.groups) ~= "table" then
    error("Crystal profile is missing world extraction metadata", 2)
  end

  local groups = Json.array({})
  local groupIds = {}
  local extractedMapIds = {}
  local trainerReferences = Json.array({})
  for _, reference in ipairs(worldProfile.trainerReferences or {}) do
    trainerReferences[#trainerReferences + 1] = reference
  end
  local spriteIds = { [1] = true, [96] = true }
  local tilesetIds = {}
  for _, groupProfile in ipairs(worldProfile.groups) do
    local group = decodeGroup(rom, profile, groupProfile)
    groups[#groups + 1] = group
    groupIds[#groupIds + 1] = group.id
    for _, map in ipairs(group.maps) do
      extractedMapIds[map.id] = true
      local maximumBlock = tilesetIds[map.tilesetId] or -1
      for _, blockId in ipairs(map.blocks) do
        if blockId > maximumBlock then
          maximumBlock = blockId
        end
      end
      tilesetIds[map.tilesetId] = maximumBlock
      for _, object in ipairs(map.objects) do
        spriteIds[object.spriteId] = true
        if object.trainer then
          trainerReferences[#trainerReferences + 1] = object.trainer
        end
      end
    end
  end

  local tilesetSpecs = Json.array({})
  for id, maximumBlock in pairs(tilesetIds) do
    local name = CrystalWorldData.tilesetName(id)
    if not name then
      error(("Crystal world profile references unsupported tileset %d")
        :format(id), 2)
    end
    tilesetSpecs[#tilesetSpecs + 1] = {
      id = id,
      name = name,
      metatileCount = maximumBlock + 1,
    }
  end
  table.sort(tilesetSpecs, function(left, right)
    return left.id < right.id
  end)

  local expectedAttributes =
    requireSymbol(profile, "NewBarkTown_MapAttributes")
  local expectedBlocks = requireSymbol(profile, "NewBarkTown_Blocks")
  local expectedEvents = requireSymbol(profile, "NewBarkTown_MapEvents")
  local newBarkGroup = findGroup(groups, 24)
  local newBark = findMap(newBarkGroup, "24:4")
  if not newBark or newBark.id ~= "24:4" then
    error("Crystal New Bark extraction catalog is inconsistent", 2)
  end
  local header = newBarkGroup.headers[4]
  if rom:offset(header.attributesBank, header.attributesAddress, 1)
      ~= expectedAttributes.offset then
    error("Crystal New Bark map attribute pointer does not match symbols", 2)
  end
  local attributesOffset = expectedAttributes.offset
  if rom:offset(
      rom:readByte(attributesOffset + 3),
      rom:readWord(attributesOffset + 4),
      1
    ) ~= expectedBlocks.offset then
    error("Crystal New Bark block pointer does not match symbols", 2)
  end
  if rom:offset(
      rom:readByte(attributesOffset + 6),
      rom:readWord(attributesOffset + 9),
      1
    ) ~= expectedEvents.offset then
    error("Crystal New Bark event pointer does not match symbols", 2)
  end

  return {
    schema = 1,
    initialMap = {
      mapId = mapId(
        worldProfile.initialMap.group,
        worldProfile.initialMap.map
      ),
      x = worldProfile.initialMap.x,
      y = worldProfile.initialMap.y,
    },
    groups = groups,
    collisionPermissions = decodeCollisionPermissions(rom, profile),
    objectPalettes = decodeObjectPalettes(rom, profile),
    roofs = decodeRoofs(rom, profile, groupIds),
    sprites = decodeSprites(rom, profile, spriteIds),
    tilesets = CrystalTileset.extractMany(rom, profile, tilesetSpecs),
    encounters = CrystalEncounterData.extract(
      rom,
      profile,
      extractedMapIds
    ),
    trainers = CrystalTrainerData.extract(
      rom,
      profile,
      trainerReferences
    ),
  }
end

return CrystalWorldData
