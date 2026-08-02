local GameBoyApu = {}
GameBoyApu.__index = GameBoyApu

local CLOCK_HZ = 4194304
local FRAME_SEQUENCER_PERIOD = 8192
local DEFAULT_SAMPLE_RATE = 48000
local HIGH_PASS_CHARGE = 0.999958

local NR10, NR52 = 0xff10, 0xff26
local WAVE_RAM_FIRST, WAVE_RAM_LAST = 0xff30, 0xff3f

local DUTY_PATTERNS = {
  [0] = { 0, 0, 0, 0, 0, 0, 0, 1 },
  [1] = { 1, 0, 0, 0, 0, 0, 0, 1 },
  [2] = { 1, 0, 0, 0, 0, 1, 1, 1 },
  [3] = { 0, 1, 1, 1, 1, 1, 1, 0 },
}
local NOISE_DIVISORS = { [0] = 8, 16, 32, 48, 64, 80, 96, 112 }
local WAVE_VOLUME_SHIFTS = { [0] = 4, 0, 1, 2 }

local PULSE_LENGTH_MAXIMUM = 64
local WAVE_LENGTH_MAXIMUM = 256

local function bitOf(value, position)
  return math.floor(value / 2 ^ position) % 2
end

local function field(value, position, width)
  return math.floor(value / 2 ^ position) % 2 ^ width
end

local function newPulse(hasSweep)
  return {
    kind = "pulse",
    hasSweep = hasSweep and true or false,
    enabled = false,
    dacEnabled = false,
    lengthCounter = 0,
    lengthEnabled = false,
    duty = 0,
    dutyStep = 0,
    frequency = 0,
    timer = 0,
    volume = 0,
    envelopeInitial = 0,
    envelopeAdd = false,
    envelopePeriod = 0,
    envelopeTimer = 0,
    sweepPeriod = 0,
    sweepNegate = false,
    sweepShift = 0,
    sweepTimer = 0,
    sweepEnabled = false,
    sweepShadow = 0,
  }
end

local function newWave()
  return {
    kind = "wave",
    enabled = false,
    dacEnabled = false,
    lengthCounter = 0,
    lengthEnabled = false,
    frequency = 0,
    timer = 0,
    position = 0,
    volumeCode = 0,
    sample = 0,
  }
end

local function newNoise()
  return {
    kind = "noise",
    enabled = false,
    dacEnabled = false,
    lengthCounter = 0,
    lengthEnabled = false,
    timer = 0,
    volume = 0,
    envelopeInitial = 0,
    envelopeAdd = false,
    envelopePeriod = 0,
    envelopeTimer = 0,
    clockShift = 0,
    widthMode = false,
    divisorCode = 0,
    lfsr = 0x7fff,
  }
end

function GameBoyApu.new(options)
  options = options or {}
  local sampleRate = options.sampleRate or DEFAULT_SAMPLE_RATE
  if type(sampleRate) ~= "number" or sampleRate <= 0 then
    error("Game Boy APU requires a positive sample rate", 2)
  end
  local apu = setmetatable({
    sampleRate = sampleRate,
    cyclesPerSample = CLOCK_HZ / sampleRate,
    highPass = options.highPass ~= false,
  }, GameBoyApu)
  apu:reset()
  return apu
end

function GameBoyApu:reset()
  self.channels = {
    newPulse(true),
    newPulse(false),
    newWave(),
    newNoise(),
  }
  self.waveRam = {}
  for index = 0, 15 do
    self.waveRam[index] = 0
  end
  self.channels[3].waveRam = self.waveRam
  self.powered = false
  self.leftVolume = 0
  self.rightVolume = 0
  self.panning = 0
  self.frameSequencerTimer = FRAME_SEQUENCER_PERIOD
  self.frameSequencerStep = 0
  self.sampleAccumulator = 0
  self.highPassLeft = 0
  self.highPassRight = 0
end

local function pulsePeriod(channel)
  return (2048 - channel.frequency) * 4
end

local function wavePeriod(channel)
  return (2048 - channel.frequency) * 2
end

local function noisePeriod(channel)
  return NOISE_DIVISORS[channel.divisorCode] * 2 ^ channel.clockShift
end

local function lengthMaximum(channel)
  if channel.kind == "wave" then
    return WAVE_LENGTH_MAXIMUM
  end
  return PULSE_LENGTH_MAXIMUM
end

local function sweepFrequency(channel)
  local delta = math.floor(channel.sweepShadow / 2 ^ channel.sweepShift)
  local candidate = channel.sweepShadow
    + (channel.sweepNegate and -delta or delta)
  if candidate > 2047 then
    channel.enabled = false
  end
  return candidate
end

local function trigger(apu, channel)
  channel.enabled = channel.dacEnabled
  if channel.lengthCounter == 0 then
    channel.lengthCounter = lengthMaximum(channel)
  end
  if channel.kind == "pulse" then
    channel.timer = pulsePeriod(channel)
  elseif channel.kind == "wave" then
    channel.timer = wavePeriod(channel)
    channel.position = 0
    channel.sample = 0
  else
    channel.timer = noisePeriod(channel)
    channel.lfsr = 0x7fff
  end
  if channel.kind ~= "wave" then
    channel.envelopeTimer = channel.envelopePeriod
    channel.volume = channel.envelopeInitial
  end
  if channel.hasSweep then
    channel.sweepShadow = channel.frequency
    channel.sweepTimer = channel.sweepPeriod > 0 and channel.sweepPeriod or 8
    channel.sweepEnabled =
      channel.sweepPeriod > 0 or channel.sweepShift > 0
    if channel.sweepShift > 0 then
      sweepFrequency(channel)
    end
  end
end

local function clockLength(channel)
  if channel.lengthEnabled and channel.lengthCounter > 0 then
    channel.lengthCounter = channel.lengthCounter - 1
    if channel.lengthCounter == 0 then
      channel.enabled = false
    end
  end
end

local function clockEnvelope(channel)
  if channel.envelopePeriod == 0 then
    return
  end
  channel.envelopeTimer = channel.envelopeTimer - 1
  if channel.envelopeTimer > 0 then
    return
  end
  channel.envelopeTimer = channel.envelopePeriod
  if channel.envelopeAdd and channel.volume < 15 then
    channel.volume = channel.volume + 1
  elseif not channel.envelopeAdd and channel.volume > 0 then
    channel.volume = channel.volume - 1
  end
end

local function clockSweep(channel)
  channel.sweepTimer = channel.sweepTimer - 1
  if channel.sweepTimer > 0 then
    return
  end
  channel.sweepTimer = channel.sweepPeriod > 0 and channel.sweepPeriod or 8
  if not channel.sweepEnabled or channel.sweepPeriod == 0 then
    return
  end
  local candidate = sweepFrequency(channel)
  if candidate <= 2047 and channel.sweepShift > 0 then
    channel.sweepShadow = candidate
    channel.frequency = candidate
    sweepFrequency(channel)
  end
end

local function clockNoise(channel)
  local feedback = (channel.lfsr % 2 + math.floor(channel.lfsr / 2) % 2) % 2
  local shifted = math.floor(channel.lfsr / 2) + feedback * 0x4000
  if channel.widthMode then
    local previous = math.floor(shifted / 64) % 2
    shifted = shifted - previous * 64 + feedback * 64
  end
  channel.lfsr = shifted
end

function GameBoyApu:_clockFrameSequencer()
  local step = self.frameSequencerStep
  if step % 2 == 0 then
    for _, channel in ipairs(self.channels) do
      clockLength(channel)
    end
  end
  if step == 2 or step == 6 then
    clockSweep(self.channels[1])
  end
  if step == 7 then
    clockEnvelope(self.channels[1])
    clockEnvelope(self.channels[2])
    clockEnvelope(self.channels[4])
  end
  self.frameSequencerStep = (step + 1) % 8
end

local function advance(channel, cycles, period, onExpire)
  channel.timer = channel.timer - cycles
  while channel.timer <= 0 do
    local reload = period(channel)
    if reload <= 0 then
      channel.timer = 1
      return
    end
    channel.timer = channel.timer + reload
    onExpire(channel)
  end
end

local function expirePulse(channel)
  channel.dutyStep = (channel.dutyStep + 1) % 8
end

local function expireWave(channel)
  channel.position = (channel.position + 1) % 32
  local byte = channel.waveRam[math.floor(channel.position / 2)] or 0
  if channel.position % 2 == 0 then
    channel.sample = math.floor(byte / 16)
  else
    channel.sample = byte % 16
  end
end

function GameBoyApu:step(cycles)
  if cycles <= 0 then
    return
  end
  if not self.powered then
    return
  end
  local remaining = cycles
  while remaining > 0 do
    local slice = math.min(remaining, self.frameSequencerTimer)
    advance(self.channels[1], slice, pulsePeriod, expirePulse)
    advance(self.channels[2], slice, pulsePeriod, expirePulse)
    advance(self.channels[3], slice, wavePeriod, expireWave)
    advance(self.channels[4], slice, noisePeriod, clockNoise)
    self.frameSequencerTimer = self.frameSequencerTimer - slice
    if self.frameSequencerTimer <= 0 then
      self.frameSequencerTimer = self.frameSequencerTimer
        + FRAME_SEQUENCER_PERIOD
      self:_clockFrameSequencer()
    end
    remaining = remaining - slice
  end
end

function GameBoyApu:channelOutput(index)
  local channel = self.channels[index]
  if not channel.enabled then
    return 0
  end
  if channel.kind == "pulse" then
    return DUTY_PATTERNS[channel.duty][channel.dutyStep + 1] * channel.volume
  elseif channel.kind == "wave" then
    return math.floor(
      channel.sample / 2 ^ WAVE_VOLUME_SHIFTS[channel.volumeCode])
  end
  return (1 - channel.lfsr % 2) * channel.volume
end

function GameBoyApu:dacOutput(index)
  local channel = self.channels[index]
  if not channel.dacEnabled then
    return 0
  end
  return self:channelOutput(index) / 7.5 - 1
end

function GameBoyApu:sample()
  if not self.powered then
    return 0, 0
  end
  local left, right = 0, 0
  for index = 1, 4 do
    local output = self:dacOutput(index)
    if bitOf(self.panning, index + 3) == 1 then
      left = left + output
    end
    if bitOf(self.panning, index - 1) == 1 then
      right = right + output
    end
  end
  left = left * (self.leftVolume + 1) / 8 / 4
  right = right * (self.rightVolume + 1) / 8 / 4
  if self.highPass then
    local filteredLeft = left - self.highPassLeft
    local filteredRight = right - self.highPassRight
    self.highPassLeft = left - filteredLeft * HIGH_PASS_CHARGE
    self.highPassRight = right - filteredRight * HIGH_PASS_CHARGE
    return filteredLeft, filteredRight
  end
  return left, right
end

function GameBoyApu:render(count, callback)
  if type(callback) ~= "function" then
    error("Game Boy APU rendering requires a sample callback", 2)
  end
  for index = 1, count do
    self.sampleAccumulator = self.sampleAccumulator + self.cyclesPerSample
    local cycles = math.floor(self.sampleAccumulator)
    self.sampleAccumulator = self.sampleAccumulator - cycles
    self:step(cycles)
    local left, right = self:sample()
    callback(index, left, right)
  end
end

local function writeEnvelope(channel, value)
  channel.envelopeInitial = field(value, 4, 4)
  channel.envelopeAdd = bitOf(value, 3) == 1
  channel.envelopePeriod = value % 8
  channel.dacEnabled = field(value, 3, 5) ~= 0
  if not channel.dacEnabled then
    channel.enabled = false
  end
end

local function writeFrequencyHigh(apu, channel, value)
  channel.frequency = channel.frequency % 256 + (value % 8) * 256
  channel.lengthEnabled = bitOf(value, 6) == 1
  if bitOf(value, 7) == 1 then
    trigger(apu, channel)
  end
end

local function powerOff(apu)
  local waveRam = apu.waveRam
  apu:reset()
  apu.waveRam = waveRam
  apu.channels[3].waveRam = waveRam
end

function GameBoyApu:writeRegister(address, value)
  if address >= WAVE_RAM_FIRST and address <= WAVE_RAM_LAST then
    self.waveRam[address - WAVE_RAM_FIRST] = value % 256
    return
  end
  if address < NR10 or address > NR52 then
    error(("address %04x is outside the Game Boy APU"):format(address), 2)
  end
  value = value % 256
  if address == NR52 then
    local powered = bitOf(value, 7) == 1
    if not powered then
      powerOff(self)
    elseif not self.powered then
      self.powered = true
      self.frameSequencerStep = 0
      self.frameSequencerTimer = FRAME_SEQUENCER_PERIOD
    end
    return
  end
  if not self.powered then
    return
  end
  local pulseOne, pulseTwo = self.channels[1], self.channels[2]
  local wave, noise = self.channels[3], self.channels[4]
  if address == 0xff10 then
    pulseOne.sweepPeriod = field(value, 4, 3)
    pulseOne.sweepNegate = bitOf(value, 3) == 1
    pulseOne.sweepShift = value % 8
  elseif address == 0xff11 or address == 0xff16 then
    local channel = address == 0xff11 and pulseOne or pulseTwo
    channel.duty = field(value, 6, 2)
    channel.lengthCounter = PULSE_LENGTH_MAXIMUM - value % 64
  elseif address == 0xff12 or address == 0xff17 then
    writeEnvelope(address == 0xff12 and pulseOne or pulseTwo, value)
  elseif address == 0xff13 or address == 0xff18 then
    local channel = address == 0xff13 and pulseOne or pulseTwo
    channel.frequency = math.floor(channel.frequency / 256) * 256 + value
  elseif address == 0xff14 or address == 0xff19 then
    writeFrequencyHigh(
      self, address == 0xff14 and pulseOne or pulseTwo, value)
  elseif address == 0xff1a then
    wave.dacEnabled = bitOf(value, 7) == 1
    if not wave.dacEnabled then
      wave.enabled = false
    end
  elseif address == 0xff1b then
    wave.lengthCounter = WAVE_LENGTH_MAXIMUM - value
  elseif address == 0xff1c then
    wave.volumeCode = field(value, 5, 2)
  elseif address == 0xff1d then
    wave.frequency = math.floor(wave.frequency / 256) * 256 + value
  elseif address == 0xff1e then
    writeFrequencyHigh(self, wave, value)
  elseif address == 0xff20 then
    noise.lengthCounter = PULSE_LENGTH_MAXIMUM - value % 64
  elseif address == 0xff21 then
    writeEnvelope(noise, value)
  elseif address == 0xff22 then
    noise.clockShift = field(value, 4, 4)
    noise.widthMode = bitOf(value, 3) == 1
    noise.divisorCode = value % 8
  elseif address == 0xff23 then
    noise.lengthEnabled = bitOf(value, 6) == 1
    if bitOf(value, 7) == 1 then
      trigger(self, noise)
    end
  elseif address == 0xff24 then
    self.leftVolume = field(value, 4, 3)
    self.rightVolume = value % 8
  elseif address == 0xff25 then
    self.panning = value
  end
end

function GameBoyApu:readRegister(address)
  if address >= WAVE_RAM_FIRST and address <= WAVE_RAM_LAST then
    return self.waveRam[address - WAVE_RAM_FIRST]
  end
  if address ~= NR52 then
    error(("address %04x is not a readable Game Boy APU port")
      :format(address), 2)
  end
  local value = self.powered and 0xf0 or 0x70
  for index = 1, 4 do
    if self.channels[index].enabled then
      value = value + 2 ^ (index - 1)
    end
  end
  return value
end

GameBoyApu.CLOCK_HZ = CLOCK_HZ
GameBoyApu.FRAME_SEQUENCER_PERIOD = FRAME_SEQUENCER_PERIOD
GameBoyApu.NOISE_DIVISORS = NOISE_DIVISORS
GameBoyApu.DUTY_PATTERNS = DUTY_PATTERNS

return GameBoyApu
