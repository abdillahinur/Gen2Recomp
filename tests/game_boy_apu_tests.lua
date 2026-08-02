return function(test, equal, truthy, raises)
  local GameBoyApu = require("src.audio.GameBoyApu")

  local function near(actual, expected, message)
    if math.abs(actual - expected) > 1e-9 then
      error((message or "values differ")
        .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual), 2)
    end
  end

  local function powered(options)
    local apu = GameBoyApu.new(options)
    apu:writeRegister(0xff26, 0x80)
    apu:writeRegister(0xff24, 0x77)
    apu:writeRegister(0xff25, 0xff)
    return apu
  end

  -- A pulse channel at frequency 2047 advances one duty step every four
  -- cycles, which keeps the golden duty vectors readable.
  local function pulseAtMaximumRate(apu, duty)
    apu:writeRegister(0xff11, duty * 64)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0xff)
    apu:writeRegister(0xff14, 0x87)
  end

  test("Game Boy APU starts powered off and ignores writes", function()
    local apu = GameBoyApu.new()
    equal(apu.powered, false)
    apu:writeRegister(0xff12, 0xf0)
    equal(apu.channels[1].dacEnabled, false)
    equal(apu:readRegister(0xff26), 0x70)
  end)

  test("Game Boy APU rejects addresses outside the sound range", function()
    local apu = GameBoyApu.new()
    raises(function()
      apu:writeRegister(0xff0f, 0)
    end, "outside the Game Boy APU")
    raises(function()
      apu:readRegister(0xff10)
    end, "not a readable Game Boy APU port")
  end)

  test("Game Boy APU reports power and channel status in NR52", function()
    local apu = powered()
    equal(apu:readRegister(0xff26), 0xf0)
    pulseAtMaximumRate(apu, 2)
    equal(apu:readRegister(0xff26), 0xf1)
  end)

  test("Game Boy APU emits the four hardware duty patterns", function()
    local expected = {
      [0] = { 0, 0, 0, 0, 0, 0, 0, 1 },
      [1] = { 1, 0, 0, 0, 0, 0, 0, 1 },
      [2] = { 1, 0, 0, 0, 0, 1, 1, 1 },
      [3] = { 0, 1, 1, 1, 1, 1, 1, 0 },
    }
    for duty = 0, 3 do
      local apu = powered()
      pulseAtMaximumRate(apu, duty)
      for step = 1, 8 do
        equal(
          apu:channelOutput(1),
          expected[duty][step] * 15,
          ("duty %d step %d"):format(duty, step))
        apu:step(4)
      end
    end
  end)

  -- An all-ones register drains one bit at a time, so the inverted output
  -- stays low for fifteen shifts before the first feedback bit arrives.
  test("Game Boy APU holds noise low for fifteen shifts", function()
    local apu = powered()
    apu:writeRegister(0xff21, 0xf0)
    apu:writeRegister(0xff22, 0x00)
    apu:writeRegister(0xff23, 0x80)
    local channel = apu.channels[4]
    equal(channel.lfsr, 0x7fff)
    for shift = 1, 15 do
      equal(channel.lfsr, 2 ^ (16 - shift) - 1, "shift " .. shift)
      equal(apu:channelOutput(4), 0, "shift " .. shift .. " stays low")
      apu:step(8)
    end
    equal(channel.lfsr, 0x4000)
    equal(apu:channelOutput(4), 15)
  end)

  test("Game Boy APU noise repeats after 32767 shifts", function()
    local apu = powered()
    apu:writeRegister(0xff21, 0xf0)
    apu:writeRegister(0xff22, 0x00)
    apu:writeRegister(0xff23, 0x80)
    local channel = apu.channels[4]
    local first = {}
    for index = 1, 32767 do
      first[index] = channel.lfsr % 2
      apu:step(8)
    end
    for index = 1, 32767 do
      equal(channel.lfsr % 2, first[index], "shift " .. index)
      apu:step(8)
    end
  end)

  test("Game Boy APU noise repeats after 127 shifts in width mode", function()
    local apu = powered()
    apu:writeRegister(0xff21, 0xf0)
    apu:writeRegister(0xff22, 0x08)
    apu:writeRegister(0xff23, 0x80)
    local channel = apu.channels[4]
    local first = {}
    for index = 1, 127 do
      first[index] = channel.lfsr % 2
      apu:step(8)
    end
    for index = 1, 127 do
      equal(channel.lfsr % 2, first[index], "shift " .. index)
      apu:step(8)
    end
  end)

  test("Game Boy APU derives noise periods from the divisor table", function()
    equal(GameBoyApu.NOISE_DIVISORS[0], 8)
    local apu = powered()
    apu:writeRegister(0xff21, 0xf0)
    apu:writeRegister(0xff22, 0x31)
    apu:writeRegister(0xff23, 0x80)
    equal(apu.channels[4].timer, 16 * 8)
  end)

  test("Game Boy APU steps the frame sequencer at 512 Hz", function()
    local apu = powered()
    equal(apu.frameSequencerStep, 0)
    for step = 1, 8 do
      apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD)
      equal(apu.frameSequencerStep, step % 8)
    end
  end)

  test("Game Boy APU clocks the envelope only on step seven", function()
    local apu = powered()
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0xf1)
    apu:writeRegister(0xff13, 0xff)
    apu:writeRegister(0xff14, 0x87)
    local channel = apu.channels[1]
    equal(channel.volume, 15)
    for _ = 1, 7 do
      apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD)
      equal(channel.volume, 15)
    end
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD)
    equal(channel.volume, 14)
  end)

  test("Game Boy APU holds volume when the envelope period is zero", function()
    local apu = powered()
    pulseAtMaximumRate(apu, 2)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD * 64)
    equal(apu.channels[1].volume, 15)
  end)

  test("Game Boy APU raises volume on an increasing envelope", function()
    local apu = powered()
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0x09)
    apu:writeRegister(0xff13, 0xff)
    apu:writeRegister(0xff14, 0x87)
    local channel = apu.channels[1]
    equal(channel.volume, 0)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD * 8)
    equal(channel.volume, 1)
  end)

  test("Game Boy APU disables a channel when its length expires", function()
    local apu = powered()
    apu:writeRegister(0xff11, 0xbf)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0xff)
    apu:writeRegister(0xff14, 0xc7)
    local channel = apu.channels[1]
    equal(channel.lengthCounter, 1)
    equal(channel.enabled, true)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD)
    equal(channel.lengthCounter, 0)
    equal(channel.enabled, false)
  end)

  test("Game Boy APU keeps playing when length is not enabled", function()
    local apu = powered()
    apu:writeRegister(0xff11, 0xbf)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0xff)
    apu:writeRegister(0xff14, 0x87)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD * 8)
    equal(apu.channels[1].enabled, true)
  end)

  test("Game Boy APU reloads a spent length counter on trigger", function()
    local apu = powered()
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff14, 0x80)
    equal(apu.channels[1].lengthCounter, 64)
  end)

  test("Game Boy APU sweeps the shadow frequency upward", function()
    local apu = powered()
    apu:writeRegister(0xff10, 0x11)
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0x00)
    apu:writeRegister(0xff14, 0x84)
    local channel = apu.channels[1]
    equal(channel.frequency, 1024)
    equal(channel.sweepShadow, 1024)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD * 3)
    equal(channel.frequency, 1536)
    equal(channel.sweepShadow, 1536)
  end)

  test("Game Boy APU sweeps downward when negation is set", function()
    local apu = powered()
    apu:writeRegister(0xff10, 0x19)
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0x00)
    apu:writeRegister(0xff14, 0x84)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD * 3)
    equal(apu.channels[1].frequency, 512)
  end)

  test("Game Boy APU disables channel one on sweep overflow", function()
    local apu = powered()
    apu:writeRegister(0xff10, 0x11)
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0xd0)
    apu:writeRegister(0xff14, 0x87)
    equal(apu.channels[1].enabled, false)
  end)

  test("Game Boy APU leaves the sweep idle when period is zero", function()
    local apu = powered()
    apu:writeRegister(0xff10, 0x01)
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0xf0)
    apu:writeRegister(0xff13, 0x00)
    apu:writeRegister(0xff14, 0x84)
    apu:step(GameBoyApu.FRAME_SEQUENCER_PERIOD * 8)
    equal(apu.channels[1].frequency, 1024)
  end)

  test("Game Boy APU plays wave RAM nibbles high half first", function()
    local apu = powered()
    apu:writeRegister(0xff30, 0x8f)
    apu:writeRegister(0xff31, 0x37)
    apu:writeRegister(0xff1a, 0x80)
    apu:writeRegister(0xff1c, 0x20)
    apu:writeRegister(0xff1d, 0xff)
    apu:writeRegister(0xff1e, 0x87)
    equal(apu:channelOutput(3), 0)
    apu:step(2)
    equal(apu:channelOutput(3), 15)
    apu:step(2)
    equal(apu:channelOutput(3), 3)
    apu:step(2)
    equal(apu:channelOutput(3), 7)
  end)

  test("Game Boy APU applies the wave volume code shifts", function()
    local shifts = { [0] = 0, 12, 6, 3 }
    for code = 0, 3 do
      local apu = powered()
      apu:writeRegister(0xff30, 0x0c)
      apu:writeRegister(0xff1a, 0x80)
      apu:writeRegister(0xff1c, code * 32)
      apu:writeRegister(0xff1d, 0xff)
      apu:writeRegister(0xff1e, 0x87)
      apu:step(2)
      equal(apu:channelOutput(3), shifts[code], "volume code " .. code)
    end
  end)

  test("Game Boy APU counts wave length to 256", function()
    local apu = powered()
    apu:writeRegister(0xff1a, 0x80)
    apu:writeRegister(0xff1b, 0xff)
    apu:writeRegister(0xff1e, 0x80)
    equal(apu.channels[3].lengthCounter, 1)
    apu:writeRegister(0xff1b, 0x00)
    apu:writeRegister(0xff1e, 0x80)
    equal(apu.channels[3].lengthCounter, 256)
  end)

  test("Game Boy APU disables a channel when its DAC is cleared", function()
    local apu = powered()
    pulseAtMaximumRate(apu, 2)
    equal(apu.channels[1].enabled, true)
    apu:writeRegister(0xff12, 0x00)
    equal(apu.channels[1].dacEnabled, false)
    equal(apu.channels[1].enabled, false)
    equal(apu:channelOutput(1), 0)
  end)

  test("Game Boy APU refuses to trigger a channel with a dead DAC", function()
    local apu = powered()
    apu:writeRegister(0xff11, 0x80)
    apu:writeRegister(0xff12, 0x00)
    apu:writeRegister(0xff14, 0x87)
    equal(apu.channels[1].enabled, false)
  end)

  test("Game Boy APU routes channels through NR51 panning", function()
    local apu = GameBoyApu.new({ highPass = false })
    apu:writeRegister(0xff26, 0x80)
    apu:writeRegister(0xff24, 0x77)
    apu:writeRegister(0xff25, 0x10)
    pulseAtMaximumRate(apu, 2)
    local left, right = apu:sample()
    near(left, 0.25)
    near(right, 0)
    apu:writeRegister(0xff25, 0x01)
    left, right = apu:sample()
    near(left, 0)
    near(right, 0.25)
  end)

  test("Game Boy APU scales output by the NR50 master volume", function()
    local apu = GameBoyApu.new({ highPass = false })
    apu:writeRegister(0xff26, 0x80)
    apu:writeRegister(0xff24, 0x30)
    apu:writeRegister(0xff25, 0x11)
    pulseAtMaximumRate(apu, 2)
    local left, right = apu:sample()
    near(left, 0.25 * 4 / 8)
    near(right, 0.25 * 1 / 8)
  end)

  test("Game Boy APU silences a channel with its DAC turned off", function()
    local apu = GameBoyApu.new({ highPass = false })
    apu:writeRegister(0xff26, 0x80)
    apu:writeRegister(0xff24, 0x77)
    apu:writeRegister(0xff25, 0xff)
    local left, right = apu:sample()
    near(left, 0)
    near(right, 0)
  end)

  test("Game Boy APU removes the DAC offset through the high pass", function()
    local apu = powered()
    pulseAtMaximumRate(apu, 2)
    local left = 0
    for _ = 1, 200000 do
      left = select(1, apu:sample())
    end
    truthy(math.abs(left) < 1e-3, "steady output should settle near zero")
  end)

  test("Game Boy APU clears state but keeps wave RAM on power off", function()
    local apu = powered()
    apu:writeRegister(0xff30, 0x5a)
    pulseAtMaximumRate(apu, 2)
    apu:writeRegister(0xff26, 0x00)
    equal(apu.powered, false)
    equal(apu.channels[1].enabled, false)
    equal(apu.panning, 0)
    equal(apu.leftVolume, 0)
    equal(apu:readRegister(0xff30), 0x5a)
    local left, right = apu:sample()
    equal(left, 0)
    equal(right, 0)
  end)

  test("Game Boy APU renders the requested number of samples", function()
    local apu = powered({ sampleRate = 48000 })
    pulseAtMaximumRate(apu, 2)
    local count = 0
    apu:render(64, function(index, left, right)
      count = count + 1
      equal(index, count)
      truthy(left >= -1 and left <= 1)
      truthy(right >= -1 and right <= 1)
    end)
    equal(count, 64)
  end)

  test("Game Boy APU keeps the sample clock at the hardware rate", function()
    local apu = powered({ sampleRate = 48000 })
    near(apu.cyclesPerSample, GameBoyApu.CLOCK_HZ / 48000)
    apu:render(48000, function() end)
    truthy(apu.sampleAccumulator >= 0 and apu.sampleAccumulator < 1)
  end)

  test("Game Boy APU rejects a non-positive sample rate", function()
    raises(function()
      GameBoyApu.new({ sampleRate = 0 })
    end, "positive sample rate")
    raises(function()
      GameBoyApu.new({ sampleRate = 48000 }):render(1, nil)
    end, "sample callback")
  end)
end
