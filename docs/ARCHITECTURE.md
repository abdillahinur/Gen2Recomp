# Architecture

## System boundary

Gen2Recomp is a native game recreation. It does not execute Game Boy machine
code or model Game Boy hardware.

```text
player-supplied G/S/C ROM
          |
          v
hash verification + immutable version profile
          |
          v
transactional ROM importer
          |
          +-- private normalized data cache
          +-- private graphics/palette cache
          +-- private map/text cache
          +-- private audio programs
          |
          v
hand-written Lua behavior + native LÖVE2D engine
```

The importer is the only production subsystem allowed to understand ROM banks,
addresses, and pointer encodings. Runtime systems consume stable IDs and
normalized records.

## Runtime layers

| Layer | Responsibility |
| --- | --- |
| `core` | Fixed-step scheduling, input, services, state stack, configuration |
| `import` | ROM identification, version profiles, extraction, cache validation |
| `render` | 160×144 canvas, CGB palettes, tiles, sprites, UI primitives |
| `world` | Maps, collision, movement, objects, warps, encounters |
| `script` | Hand-written map scripts, coroutine runner, reusable Lua commands |
| `pokemon` | Species, instances, stats, growth, evolution, breeding |
| `battle` | Deterministic simulation, AI, effects, catching, experience |
| `audio` | Music/SFX/cry command playback and native channel synthesis |
| `systems` | RTC, phone, Pokégear, daycare, Battle Tower, Mystery Gift |
| `save` | Versioned native saves, backup/recovery, optional cartridge codec |
| `ui` | Menus, party, Pack, Pokédex, PC, naming, shops, dialogue |

## Determinism

Gameplay advances at 60 fixed logic steps per second. Rendering may run at a
different rate and receives an interpolation alpha.

Sources of nondeterminism must be injectable:

- random-number generation;
- real-time clock;
- link/network transport;
- filesystem/cache location.

This enables repeatable tests and differential comparison with the original
game.

## Version profiles

Every accepted ROM hash maps to one immutable profile. A profile owns:

- identity and expected hash;
- feature flags;
- extraction symbols and table schemas;
- text, map, graphics, and audio data layouts;
- version-specific quirks;
- cache schema compatibility.

Gold and Silver will share a GS family layer. Crystal will have its own family
layer. Runtime code should query capabilities or named rules rather than check
game-name strings throughout the engine.

## Hand-written behavior

The ROM importer supplies static content. It may decode map dimensions, block
layouts, palettes, collision, connections, warps, signs, object metadata, and
text. It does not execute or translate the original event bytecode.

Map-specific behavior lives in source-controlled Lua files under
`data/scripts/`. Those scripts use a small native command API for dialogue,
choices, flags, scenes, battles, movement, object visibility, map changes,
audio, and other blocking actions. A coroutine runner lets those high-level
commands wait naturally without recreating the Game Boy script VM.

Every hand-written map behavior should cite the corresponding `pokecrystal` or
`pokegold` source file or label. Coverage is tracked by maps, scenes,
callbacks, interactions, and story gates—not by ROM opcode coverage.

Complex original routines are rewritten as named Lua systems or functions.
Their behavior is tested directly rather than dispatched by assembly address.

## Packaged application

The final product is a native desktop application, not a project that the
player opens through an emulator. Windows packaging will fuse or bundle the
Lua game with LÖVE as `Gen2Recomp.exe` plus the runtime libraries required by
LÖVE. A ZIP and/or installer can carry those files.

The packaged application contains the hand-written engine and extraction
metadata, but no ROM or pre-extracted game content. Its first-launch flow owns
ROM selection, verification, cache creation, and game startup. Once a valid
cache exists, normal launches do not require the ROM.

## Saves and RTC

Normal play uses a deliberately versioned native save model with atomic writes
and a backup. A cartridge `.sav` codec is a later interoperability feature,
not the engine's internal state representation.

All calendar and clock behavior must use one clock provider. Tests may freeze
or advance that provider without changing the host clock.

## Cache ownership

Private cache keys include:

- ROM profile ID;
- exact ROM SHA-1;
- cache schema version;
- importer build/version.

A cache is promoted only after validation succeeds. ROM data must not remain
reachable from runtime services after import.

The cache manifest is a data-only JSON document written after all payloads
have been fingerprinted. It binds the cache to the application ID, immutable
ROM profile and hash, profile cache schema, and importer version. Generated
file paths are relative and cannot escape the private cache directory. See
[`CACHE_FORMAT.md`](CACHE_FORMAT.md) for the complete ownership and lifecycle
contract.

## Current implementation

M0 provides:

- the LÖVE entry point;
- fixed-step scheduling;
- action-based input;
- stack-based application states;
- a non-game bootstrap state;
- the initial Crystal profile registry;
- headless tests.

M1 has added a bounds-checked ROM reader, streaming SHA-1, cartridge-header
parsing, exact profile identification, and the private-cache ownership model.
Absolute file offsets are zero-based. Banked reads use the Game Boy CPU ROM
windows: bank 0 addresses `0x0000–0x3fff`, and switchable banks 1+ addresses
`0x4000–0x7fff`. Banked reads may not cross their address window.

ROM identity is established by exact SHA-1. Header metadata, the header
checksum, and the declared file size are independent structural checks against
the matched profile. The legacy global checksum is reported as a warning
because it is not an identity mechanism and is not enforced by Game Boy
hardware.

The project does not yet contain the first-launch file picker, a cache writer,
game content, or gameplay.
