local CrystalSoundSynth = require("src.audio.CrystalSoundSynth")

local LoveAudioSink = {}
LoveAudioSink.__index = LoveAudioSink

function LoveAudioSink.new(programs, loveAudio, loveSound)
  if type(programs) ~= "table" or programs.schema ~= 1 then
    error("LÖVE audio sink requires decoded Crystal audio programs", 2)
  end
  return setmetatable({
    programs = programs,
    audio = loveAudio or love.audio,
    sound = loveSound or love.sound,
    cache = {},
    music = nil,
    oneShots = {},
  }, LoveAudioSink)
end

function LoveAudioSink:_source(id, kind)
  local key = kind .. ":" .. id
  if not self.cache[key] then
    local header
    local options = { kind = kind, allowLoops = kind == "music" }
    if kind == "music" then
      header = self.programs.music[id]
    elseif kind == "sfx" then
      header = self.programs.sfx[id]
      options.maximumSeconds = 5
      options.allowLoops = false
    else
      local cry = self.programs.cries[id]
      if cry then
        header = cry
        options.maximumSeconds = 4
        options.allowLoops = false
        options.frequencyOffset = cry.frequencyOffset
        options.frameTicks = 0x100 + cry.length
      end
    end
    if not header then
      error("Crystal " .. kind .. " is not extracted for " .. id, 2)
    end
    local rendered = CrystalSoundSynth.render(
      self.programs, header, options)
    local soundData = CrystalSoundSynth.soundData(rendered, self.sound)
    self.cache[key] = self.audio.newSource(soundData, "static")
  end
  return self.cache[key]:clone()
end

function LoveAudioSink:playMusic(id)
  self:stopMusic()
  self.music = self:_source(id, "music")
  self.music:setLooping(true)
  self.music:play()
end

function LoveAudioSink:stopMusic()
  if self.music then self.music:stop() end
  self.music = nil
end

function LoveAudioSink:_playOneShot(id, kind)
  local source = self:_source(id, kind)
  self.oneShots[#self.oneShots + 1] = source
  source:play()
end

function LoveAudioSink:playSfx(id)
  self:_playOneShot(id, "sfx")
end

function LoveAudioSink:playCry(id)
  self:_playOneShot(id, "cry")
end

function LoveAudioSink:update()
  local active = {}
  for _, source in ipairs(self.oneShots) do
    if source:isPlaying() then active[#active + 1] = source end
  end
  self.oneShots = active
end

return LoveAudioSink
