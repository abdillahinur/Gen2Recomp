return function(test, equal, truthy)
  local CrystalSoundSynth = require("src.audio.CrystalSoundSynth")

  local function bank(bytes)
    return bytes .. string.rep("\0", 0x4000 - #bytes)
  end

  test("Crystal sound synth decodes music notes and timing", function()
    local bytes = string.char(
      0x00, 0x03, 0x40,
      0xda, 0x01, 0x00,
      0xd8, 0x01, 0xf1,
      0xd4,
      0x10,
      0xff
    )
    local programs = {
      schema = 1,
      sampleRate = 22050,
      programBanks = { [1] = bank(bytes) },
    }
    local rendered = CrystalSoundSynth.render(
      programs, { bank = 1, address = 0x4000 },
      { kind = "music", maximumSeconds = 1, allowLoops = false }
    )
    equal(#rendered.channels, 1)
    equal(rendered.channels[1][1].kind, "pulse")
    truthy(math.abs(rendered.duration - 1 / 60) < 1e-9)
    truthy(rendered.channels[1][1].register > 0)
  end)

  test("Crystal sound synth decodes raw SFX channel notes", function()
    local bytes = string.char(
      0x04, 0x03, 0x40,
      0x06, 0xf1, 0xe8, 0x03,
      0xff
    )
    local programs = {
      schema = 1,
      sampleRate = 22050,
      programBanks = { [1] = bank(bytes) },
    }
    local rendered = CrystalSoundSynth.render(
      programs, { bank = 1, address = 0x4000 },
      { kind = "sfx", maximumSeconds = 1, allowLoops = false }
    )
    local event = rendered.channels[1][1]
    equal(event.kind, "pulse")
    equal(event.register, 1000)
    equal(event.volume, 15)
    truthy(math.abs(rendered.duration - 0.1) < 1e-9)
  end)
end
