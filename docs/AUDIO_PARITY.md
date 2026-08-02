# Audio parity notes

These notes record what has been verified about Crystal audio parity and what
the native APU layer is expected to model. They are written from behavior
observed in the pinned reference disassembly named in
`references/pokecrystal11.lock.json`; no reference source or ROM content is
reproduced here.

## Channel program operand-length audit

`src/audio/CrystalSoundSynth.lua` reads a channel program as a byte stream. If
any command consumed the wrong number of operand bytes, the reader would
desynchronize and every later note in that channel would decode as garbage
while still parsing cleanly. Nothing in the current test suite would catch
that, so the table was audited before building further layers on top of it.

Every command branch was compared against the macro definitions in
`macros/scripts/audio.asm` and, for the two commands whose operand count is
conditional, against the handlers in `audio/engine.asm`, at reference commit
`3438c7003a57fa2987fcb223d14b660761b33c64`.

**Result: the operand lengths are correct.** All command branches consume the
same number of bytes as the reference engine, including both conditional
cases:

- `$d8` (`note_type` / `drum_speed`) reads a length byte, then reads a volume
  envelope byte only when the channel is not the noise channel. `Music_NoteType`
  returns early on channel 4, and the implementation's `hardware ~= 4` guard
  matches.
- `$e3` / `$f0` (`toggle_noise` / `sfx_toggle_noise`) are not symmetric
  toggles. `Music_ToggleNoise` reads a drum-kit byte only on the off-to-on
  transition and reads nothing on the on-to-off transition. The
  implementation's `if not state.noiseEnabled then reader:byte() end` matches.

Octave mapping was checked in the same pass: `$d0` selects octave 8 and `$d7`
selects octave 1, matching the reference `octave` macro.

The stream framing is therefore sound, and the sequencing defects that remain
are behavioral rather than structural. The commands below are parsed with the
correct width but their operands are currently discarded, which is why the
rendered output diverges:

| Command | Purpose | Current handling |
| --- | --- | --- |
| `$dd` | pitch sweep | operand read, discarded |
| `$e0` | pitch slide | operands read, discarded |
| `$e1` | vibrato | operands read, discarded |
| `$e2`, `$e7`, `$e8` | engine-internal | operands read, discarded |
| `$e5` | master volume | operand read, discarded |
| `$eb` | new song | operand read, discarded |
| `$ec`, `$ed` | SFX priority | no effect on routing |
| `$ee` | engine-internal | operands read, discarded |

## Native APU scope

`src/audio/GameBoyApu.lua` models the sound hardware only. It accepts register
writes in the `$ff10`-`$ff26` range plus wave RAM at `$ff30`-`$ff3f`, advances
on CPU cycles, and produces stereo samples. It holds no ROM data, no channel
program state, and no knowledge of Crystal's sound engine, so it can be driven
by a future frame-stepped driver without further change.

Modeled behavior:

- a 512 Hz frame sequencer driving length at 256 Hz, sweep at 128 Hz, and
  volume envelopes at 64 Hz;
- the four hardware duty patterns with per-step phase;
- the 15-bit and 7-bit noise LFSR with the `NR43` divisor and shift;
- wave playback from wave RAM with the four volume codes;
- frequency sweep including the overflow disable check;
- per-channel DAC enable, `NR51` panning, and `NR50` master volume;
- a high-pass filter that removes the DC offset an enabled DAC introduces.

Deliberately out of scope, because Crystal's driver writes registers at a fixed
point in the frame and never depends on them: the sweep negate-clear quirk, the
extra length clock when length is enabled mid-period, wave RAM access conflicts
during playback, and the sample-buffer retention quirk on wave retrigger. Add
these only if a differential test shows them mattering.

## Known non-parity items

`M5-020` in `docs/BACKLOG.md` is checked off, but the synthesis it describes —
sequencing, looping, fades, stereo routing, SFX priority, and cry modifiers —
is not implemented to parity. The current renderer decodes each channel to a
flat event list with fixed start and duration, mixed to mono at 22050 Hz.
Per-frame behavior cannot be expressed in that model. Treat the `M5P` items as
the real state of this area.
