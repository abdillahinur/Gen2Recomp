local LoveAudioSink = {}
LoveAudioSink.__index = LoveAudioSink

local RATE = 22050

local function hash(id)
  local value = 2166136261
  for index = 1, #id do
    value = (value * 16777619 + id:byte(index)) % 4294967296
  end
  return value
end

local function wave(loveAudio, loveSound, id, kind)
  local duration = kind == "music" and 2
    or kind == "cry" and 0.45 or 0.12
  local samples = math.floor(RATE * duration)
  local data = loveSound.newSoundData(samples, RATE, 16, 1)
  local seed = hash(id)
  local base = 110 + seed % 330
  for index = 0, samples - 1 do
    local time = index / RATE
    local frequency = base
    if kind == "music" then
      local step = math.floor(time * 8) % 4
      frequency = base * ({ 1, 1.25, 1.5, 1.25 })[step + 1]
    elseif kind == "cry" then
      frequency = base * (1.5 - time)
    end
    local phase = (time * frequency) % 1
    local raw = phase < 0.5 and 1 or -1
    local envelope = kind == "music" and 0.10
      or math.max(0, 1 - time / duration) * 0.18
    data:setSample(index, raw * envelope)
  end
  return loveAudio.newSource(data, "static")
end

function LoveAudioSink.new(loveAudio, loveSound)
  return setmetatable({
    audio = loveAudio or love.audio,
    sound = loveSound or love.sound,
    cache = {},
    music = nil,
  }, LoveAudioSink)
end

function LoveAudioSink:_source(id, kind)
  local key = kind .. ":" .. id
  if not self.cache[key] then
    self.cache[key] = wave(self.audio, self.sound, id, kind)
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

function LoveAudioSink:playSfx(id)
  self:_source(id, "sfx"):play()
end

function LoveAudioSink:playCry(id)
  self:_source(id, "cry"):play()
end

return LoveAudioSink
