local CrystalSoundSynth = {}

local TICKS_PER_SECOND = 15360
local DEFAULT_TEMPO = 0x100
local PITCHES = {
  0xf82c, 0xf89d, 0xf907, 0xf96b, 0xf9ca, 0xfa23,
  0xfa77, 0xfac7, 0xfb12, 0xfb58, 0xfb9b, 0xfbda,
}
local DUTY = { 0.125, 0.25, 0.5, 0.75 }

local function bit(value, position)
  return math.floor(value / 2 ^ position) % 2
end

local function signedNibble(value)
  return value >= 8 and -(value - 8) or value
end

local function signedByte(value)
  return value >= 0x80 and value - 0x100 or value
end

local Reader = {}
Reader.__index = Reader

function Reader.new(programs, bank, address)
  return setmetatable({
    programs = programs,
    bank = bank,
    address = address,
  }, Reader)
end

function Reader:byte()
  local bytes = self.programs.programBanks[self.bank]
  if not bytes then error("uncached Crystal audio bank " .. self.bank, 2) end
  local index = self.address - 0x4000 + 1
  local value = bytes:byte(index)
  if not value then
    error(("Crystal audio read outside %02x:%04x")
      :format(self.bank, self.address), 2)
  end
  self.address = self.address + 1
  return value
end

function Reader:word()
  return self:byte() + self:byte() * 0x100
end

function Reader:bigword()
  return self:byte() * 0x100 + self:byte()
end

local function headerChannels(programs, header)
  local reader = Reader.new(programs, header.bank, header.address)
  local channels = {}
  local descriptor = reader:byte()
  local count = math.floor(descriptor / 0x40) + 1
  for index = 1, count do
    if index > 1 then descriptor = reader:byte() end
    channels[index] = {
      number = descriptor % 16 + 1,
      address = reader:word(),
      bank = header.bank,
    }
  end
  return channels
end

local function frequency(note, octave, transpose, offset)
  local absolute = (octave - 1) * 12 + note - 1 + transpose
  local pitch = absolute % 12
  local actualOctave = math.floor(absolute / 12) + 1
  local signed = PITCHES[pitch + 1] - 0x10000
  local divisor = 2 ^ math.max(0, actualOctave - 1)
  local register = math.floor(signed / divisor) % 0x800
  return (register + offset) % 0x800
end

local function channelEvents(programs, spec, options, shared)
  local reader = Reader.new(programs, spec.bank, spec.address)
  local hardware = (spec.number - 1) % 4 + 1
  local sfx = spec.number > 4
  local executeMusic = not sfx
  local time = 0
  local maximum = options.maximumSeconds
  local state = {
    speed = 12,
    volume = 12,
    fade = 0,
    duty = 2,
    octave = 4,
    transpose = 0,
    frequencyOffset = options.frequencyOffset or 0,
    callStack = {},
    loopCounts = {},
    condition = 0,
    noiseEnabled = false,
    panLeft = true,
    panRight = true,
  }
  local events = {}

  local function duration(length)
    if sfx and not executeMusic then
      return length * (options.frameTicks or 256) / TICKS_PER_SECOND
    end
    return length * state.speed * shared.tempo / TICKS_PER_SECOND
  end

  local function add(kind, seconds, values)
    if seconds <= 0 then return end
    values = values or {}
    values.kind = kind
    values.start = time
    values.duration = math.min(seconds, maximum - time)
    values.hardware = hardware
    values.volume = values.volume or state.volume
    values.fade = values.fade == nil and state.fade or values.fade
    values.duty = values.duty or DUTY[state.duty + 1]
    values.panLeft = state.panLeft
    values.panRight = state.panRight
    events[#events + 1] = values
    time = time + seconds
  end

  local guard = 0
  while time < maximum and guard < 500000 do
    guard = guard + 1
    local commandAddress = reader.address
    local command = reader:byte()
    if executeMusic and command < 0xd0 then
      local pitch = math.floor(command / 16)
      local length = command % 16 + 1
      if pitch == 0 then
        add("silence", duration(length))
      elseif hardware == 4 or state.noiseEnabled then
        add("noise", duration(length), { instrument = pitch })
      else
        add(hardware == 3 and "wave" or "pulse", duration(length), {
          register = frequency(
            pitch, state.octave, state.transpose,
            state.frequencyOffset),
        })
      end
    elseif sfx and not executeMusic and command < 0xd0 then
      local length = command
      local packed = reader:byte()
      local volume = math.floor(packed / 16)
      local fade = signedNibble(packed % 16)
      if hardware == 4 then
        add("noise", duration(length), {
          volume = volume,
          fade = fade,
          parameter = reader:byte(),
        })
      else
        add(hardware == 3 and "wave" or "pulse", duration(length), {
          volume = volume,
          fade = fade,
          register = (reader:word() + state.frequencyOffset) % 0x800,
        })
      end
    elseif command >= 0xd0 and command <= 0xd7 then
      state.octave = 8 - (command - 0xd0)
    elseif command == 0xd8 then
      state.speed = reader:byte()
      if hardware ~= 4 then
        local packed = reader:byte()
        state.volume = math.floor(packed / 16)
        state.fade = signedNibble(packed % 16)
      end
    elseif command == 0xd9 then
      local packed = reader:byte()
      state.transpose = math.floor(packed / 16) * 12 + packed % 16
    elseif command == 0xda then
      shared.tempo = reader:bigword()
    elseif command == 0xdb then
      state.duty = reader:byte() % 4
    elseif command == 0xdc then
      local packed = reader:byte()
      state.volume = math.floor(packed / 16)
      state.fade = signedNibble(packed % 16)
    elseif command == 0xdd then
      reader:byte()
    elseif command == 0xde then
      state.duty = math.floor(reader:byte() / 64)
    elseif command == 0xdf then
      executeMusic = not executeMusic
    elseif command == 0xe0 then
      reader:byte()
      reader:byte()
    elseif command == 0xe1 then
      reader:byte()
      reader:byte()
    elseif command == 0xe2 then
      reader:byte()
    elseif command == 0xe3 or command == 0xf0 then
      if not state.noiseEnabled then reader:byte() end
      state.noiseEnabled = not state.noiseEnabled
    elseif command == 0xe4 or command == 0xef then
      local packed = reader:byte()
      state.panLeft = math.floor(packed / 16) ~= 0
      state.panRight = packed % 16 ~= 0
    elseif command == 0xe5 then
      reader:byte()
    elseif command == 0xe6 then
      state.frequencyOffset = reader:bigword()
    elseif command == 0xe7 or command == 0xe8 then
      reader:byte()
    elseif command == 0xe9 then
      shared.tempo = math.max(1, shared.tempo + signedByte(reader:byte()))
    elseif command == 0xea then
      reader.address = reader:word()
    elseif command == 0xeb then
      reader:word()
    elseif command == 0xec or command == 0xed then
      -- Priority affects routing, not the rendered waveform.
    elseif command == 0xee then
      reader:word()
    elseif command >= 0xf1 and command <= 0xf9 then
      -- Unused/engine-control commands have no operands.
    elseif command == 0xfa then
      state.condition = reader:byte()
    elseif command == 0xfb then
      local condition, target = reader:byte(), reader:word()
      if condition == state.condition then reader.address = target end
    elseif command == 0xfc then
      reader.address = reader:word()
    elseif command == 0xfd then
      local count, target = reader:byte(), reader:word()
      if count == 0 then
        if options.allowLoops == false then break end
        reader.address = target
      else
        local remaining = state.loopCounts[commandAddress] or count
        remaining = remaining - 1
        if remaining > 0 then
          state.loopCounts[commandAddress] = remaining
          reader.address = target
        else
          state.loopCounts[commandAddress] = nil
        end
      end
    elseif command == 0xfe then
      state.callStack[#state.callStack + 1] = reader.address + 2
      reader.address = reader:word()
    elseif command == 0xff then
      local returnAddress = table.remove(state.callStack)
      if returnAddress then reader.address = returnAddress else break end
    else
      error(("unsupported Crystal audio command %02x at %02x:%04x")
        :format(command, spec.bank, commandAddress), 2)
    end
  end
  if guard >= 500000 then error("Crystal audio program did not advance", 2) end
  return events, time
end

local function envelope(event, elapsed)
  if event.fade == 0 then return event.volume / 15 end
  local stepSeconds = math.abs(event.fade) / 64
  if stepSeconds == 0 then return event.volume / 15 end
  local steps = math.floor(elapsed / stepSeconds)
  local value = event.fade > 0
    and math.max(0, event.volume - steps)
    or math.min(15, event.volume + steps)
  return value / 15
end

local function sampleEvent(event, elapsed, noiseState)
  local volume = envelope(event, elapsed) * 0.18
  if event.kind == "silence" then return 0 end
  if event.kind == "noise" then
    local parameter = event.parameter or event.instrument or 1
    local rate = 1800 + (parameter % 32) * 140
    local step = math.floor(elapsed * rate)
    local value = (step * 1103515245 + parameter * 12345) % 65536
    noiseState.value = value
    return (value < 32768 and -1 or 1) * volume
  end
  local denominator = 2048 - event.register
  if denominator <= 0 then return 0 end
  local hz = (event.kind == "wave" and 65536 or 131072) / denominator
  local phase = (elapsed * hz) % 1
  if event.kind == "wave" then
    return (phase < 0.5 and phase * 4 - 1
      or 3 - phase * 4) * volume * 0.7
  end
  return (phase < event.duty and 1 or -1) * volume
end

function CrystalSoundSynth.render(programs, header, options)
  options = options or {}
  local maximum = options.maximumSeconds
    or (options.kind == "music" and 32 or 4)
  local shared = { tempo = DEFAULT_TEMPO }
  local channels = headerChannels(programs, header)
  local eventSets = {}
  local duration = 0
  for index, spec in ipairs(channels) do
    local events, channelDuration = channelEvents(programs, spec, {
      maximumSeconds = maximum,
      allowLoops = options.allowLoops,
      frequencyOffset = options.frequencyOffset,
      frameTicks = options.frameTicks,
    }, shared)
    eventSets[index] = events
    duration = math.max(duration, channelDuration)
  end
  duration = math.min(maximum, math.max(duration, 1 / 60))
  return {
    sampleRate = programs.sampleRate or 22050,
    duration = duration,
    channels = eventSets,
  }
end

function CrystalSoundSynth.soundData(rendered, loveSound)
  local rate = rendered.sampleRate
  local sampleCount = math.max(1, math.floor(rendered.duration * rate))
  local data = loveSound.newSoundData(sampleCount, rate, 16, 1)
  local cursors = {}
  local noiseStates = {}
  for index = 1, #rendered.channels do
    cursors[index] = 1
    noiseStates[index] = { value = index }
  end
  for sample = 0, sampleCount - 1 do
    local now = sample / rate
    local mixed = 0
    for channelIndex, events in ipairs(rendered.channels) do
      local cursor = cursors[channelIndex]
      local event = events[cursor]
      while event and now >= event.start + event.duration do
        cursor = cursor + 1
        event = events[cursor]
      end
      cursors[channelIndex] = cursor
      if event and now >= event.start then
        mixed = mixed + sampleEvent(
          event, now - event.start, noiseStates[channelIndex])
      end
    end
    data:setSample(sample, math.max(-1, math.min(1, mixed)))
  end
  return data
end

return CrystalSoundSynth
