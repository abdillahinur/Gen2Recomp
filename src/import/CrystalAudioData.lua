local CrystalAudioData = {}

local MUSIC = {
  ["crystal.music.battle"] = "Music_JohtoTrainerBattle",
  ["crystal.music.cherrygrove_and_routes"] = "Music_Route30",
  ["crystal.music.cherrygrove_city"] = "Music_CherrygroveCity",
  ["crystal.music.johto_overworld"] = "Music_Route30",
  ["crystal.music.mom"] = "Music_Mom",
  ["crystal.music.new_bark_and_route_29"] = "Music_Route29",
  ["crystal.music.new_bark_town"] = "Music_NewBarkTown",
  ["crystal.music.prof_oak"] = "Music_ProfOak",
  ["crystal.music.rival_encounter"] = "Music_LookRival",
  ["crystal.music.route_30"] = "Music_Route30",
  ["crystal.music.show_me_around"] = "Music_ShowMeAround",
  ["crystal.music.violet_city_and_routes"] = "Music_VioletCity",
}

local SFX = {
  ["crystal.sfx.caught_pokemon"] = "Sfx_CaughtMon",
  ["crystal.sfx.get_badge"] = "Sfx_GetBadge",
  ["crystal.sfx.glass_ting"] = "Sfx_GlassTing",
  ["crystal.sfx.menu_open"] = "Sfx_Menu",
  ["crystal.sfx.register_phone_number"] = "Sfx_RegisterPhoneNumber",
  ["crystal.sfx.sandstorm"] = "Sfx_Sandstorm",
  ["crystal.sfx.tackle"] = "Sfx_Tackle",
  ["crystal.sfx.warp"] = "Sfx_WarpFrom",
}

local PROGRAM_BANKS = { 0x3a, 0x3b, 0x3c, 0x3d }

local function symbol(profile, name)
  local value = profile.symbols and profile.symbols[name]
  if type(value) ~= "table"
      or type(value.bank) ~= "number"
      or type(value.address) ~= "number"
      or type(value.offset) ~= "number" then
    error("Crystal audio profile is missing symbol " .. name, 3)
  end
  return value
end

local function header(profile, name)
  local value = symbol(profile, name)
  return {
    bank = value.bank,
    address = value.address,
    symbol = name,
  }
end

local function mapHeaders(profile, definitions)
  local result = {}
  for id, name in pairs(definitions) do result[id] = header(profile, name) end
  return result
end

local function extractCries(rom, profile, species)
  local speciesCries = symbol(profile, "PokemonCries").offset
  local cryHeaders = symbol(profile, "Cries").offset
  local result = {}
  for _, record in ipairs(species or {}) do
    local number = record.nationalNumber
      or record.speciesNumber or record.number
      or tonumber(record.id and record.id:match(
        "^crystal%.species%.(%d+)%."))
    if type(record.id) == "string"
        and type(number) == "number"
        and number >= 1 and number <= 251 then
      local entry = speciesCries + (number - 1) * 6
      local cryIndex = rom:readWord(entry)
      local pointer = cryHeaders + cryIndex * 3
      local cry = {
        bank = rom:readByte(pointer),
        address = rom:readWord(pointer + 1),
        frequencyOffset = rom:readWord(entry + 2),
        length = rom:readWord(entry + 4),
        speciesNumber = number,
      }
      result[record.id] = cry
      local slug = record.id:match("^crystal%.species%.%d+%.(.+)$")
      if slug then result["crystal.species." .. slug] = cry end
    end
  end
  return result
end

function CrystalAudioData.extract(rom, profile, battle)
  local banks = {}
  for _, bank in ipairs(PROGRAM_BANKS) do
    banks[bank] = rom:readString(bank * 0x4000, 0x4000)
  end
  return {
    schema = 1,
    profileId = profile.id,
    sampleRate = 22050,
    programBanks = banks,
    music = mapHeaders(profile, MUSIC),
    sfx = mapHeaders(profile, SFX),
    cries = extractCries(rom, profile, battle and battle.species),
    provenance = {
      repository = "https://github.com/pret/pokecrystal",
      sourceCommit = profile.source and profile.source.sourceCommit,
      layout = "macros/scripts/audio.asm",
    },
  }
end

return CrystalAudioData
