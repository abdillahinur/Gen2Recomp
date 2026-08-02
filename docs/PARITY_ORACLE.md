# Cartridge parity oracle

## What the existing checks prove

The nine Crystal checks remain useful structural and reachability gates. They
verify imported records, native behavior, save/RTC handling, live audio-source
creation, and that seven application states can render PNG files. They do not
compare a framebuffer, state timeline, or PCM stream against Pokémon Crystal.

The canonical structural command is therefore:

```powershell
./scripts/verify-crystal-structural.ps1 -RomPath "D:\path\to\your\ROM"
```

`verify-crystal-fidelity.ps1` remains only as a warning compatibility alias.
It must not be used as evidence of cartridge parity.

## Scenario contract

A committed scenario is input and metadata, never captured game content. Schema
1 requires:

- a stable scenario ID;
- the ROM profile and exact SHA-1;
- CGB/DMG model and boot-ROM policy;
- a fixed RTC value and explicit power-on or savestate start;
- sorted, frame-indexed complete button states;
- exact framebuffer geometry/format, required state observations, and
  audio format/sample counts for every checkpoint.

Frame 0 is the first emulated frame: install its complete input state, execute
one frame, then capture its framebuffer and state. A listed input remains held
until the next input entry replaces the complete button state. Audio windows
are half-open (`startFrame <= frame < endFrame`) and contain only samples
produced while executing those frames.

See `manifests/parity/examples/contract_synthetic.json`. The checked-in example
only exercises contract tooling; it is not a Crystal parity claim.

Every producer writes a local `run.json` beside these private artifacts:

```text
private/parity/<scenario>/<producer>/
  run.json
  frames/<frame>.rgba
  states/<frame>.json
  audio/<window>.pcm16le
```

Frame artifacts are uncompressed, top-left-origin, row-major RGBA8888 bytes.
Audio artifacts are interleaved signed 16-bit little-endian stereo PCM. The
scenario pins frame dimensions, audio sample rate, and each window's exact
sample count. State artifacts are JSON objects containing every observation
key declared by that checkpoint. The run manifest pins the exact scenario-file
SHA-256, producer name/version/config digest, and the SHA-256 of every artifact.
Paths must be relative and cannot escape the run directory. Reference and
candidate manifests must reside in distinct artifact roots, so accidentally
comparing a run to itself fails closed.

The `private/` tree is already prohibited from source control. Scenario files,
tools, normalized metrics, and non-reversible digests may be committed; ROMs,
saves, screenshots, recordings, and extracted assets may not.

## Comparator

Run:

```powershell
python tools/parity_contract.py `
  --scenario manifests/parity/<scenario>.json `
  --reference private/parity/<scenario>/reference/run.json `
  --candidate private/parity/<scenario>/native/run.json
```

The comparator validates the scenario digest, pinned media formats, required
state observations, and both artifact inventories before comparing content. It
reports the first differing pixel coordinate, state frame, or PCM
sample/channel. Synthetic tests prove that one-pixel, one-frame, one-state,
one-channel, scenario-digest, sample-count, self-comparison, and artifact-digest
errors fail independently. Schema 1 compares raw PCM exactly; a later schema
may add an explicitly pinned tolerance only if the selected reference mixer's
documented output makes byte equality invalid.

## Reference-runner spike

mGBA is the provisional automation candidate, not yet the pinned ground truth.
Its official Lua API exposes the current frame, complete key-state updates,
single-frame execution, savestates, and screenshots. Those capabilities cover
the scenario input and visual/state sides of this contract. The current public
API does not document a headless workflow or raw audio export, so P0 must prove
startup automation, fixed RTC, raw framebuffer conversion, and stereo capture
on the actual pinned build before selection.

SameBoy remains the accuracy cross-check. Its documented textual debugger
exposes LCD, palette, APU, and wave-RAM state, but its public debugger contract
does not supply the same frame-indexed input/screenshot automation surface.

Primary references:

- <https://mgba.io/docs/scripting.html>
- <https://sameboy.github.io/debugger/>

The runner decision is technical: choose the pinned build that satisfies the
complete contract. Escalate only if two compliant runners produce materially
different reference output.

## Exit criteria

P0 is complete when the same committed scenario drives both the selected
reference runner and the native runtime; both emit validated run manifests;
synthetic negative tests remain green; and an intentional native mismatch
produces an actionable local diff without committing any private game content.
