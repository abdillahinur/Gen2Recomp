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

Cache construction occurs in a unique sibling staging directory. The manifest
is written last and the complete tree is re-read and fingerprint-verified
before promotion. A valid matching target is immutable and reused. An invalid
target is quarantined and restored if the staging-directory rename fails.
Cooperative cancellation removes only the active staging directory. Startup
recovery prefers a valid target, can finish promotion of a complete staged
cache, removes incomplete staging data, and restores a quarantined prior
directory when promotion was interrupted.

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
parsing, exact profile identification, transactional private-cache ownership,
cancellation/recovery, pinned symbol generation, normalized Crystal
font/species/Johto-tileset extraction, progress reporting, and raw-retention
auditing. Absolute file offsets are zero-based. Banked reads use the Game Boy
CPU ROM windows: bank 0 addresses `0x0000–0x3fff`, and switchable banks 1+
addresses `0x4000–0x7fff`. Banked reads may not cross their address window.

ROM identity is established by exact SHA-1. Header metadata, the header
checksum, and the declared file size are independent structural checks against
the matched profile. The legacy global checksum is reported as a warning
because it is not an identity mechanism and is not enforced by Game Boy
hardware.

M2 extends that boundary with normalized map-group headers, attributes, block
layouts, connections, event metadata, collision permissions, roofs, object
palettes, and referenced overworld sprites. Its native runtime provides a
160×144 nearest-neighbor canvas, tile/sprite rendering, an injectable
time-of-day provider, map grids, camera tracking, grid movement and facing,
terrain and object collision, map connections, and reciprocal warps.

The current player-ROM-gated world slice extracts eight maps around New Bark,
four required tilesets, and sixteen referenced sprites. New Bark itself renders
and can be explored. The west connection can be crossed on foot into Route 29;
the east Route 27 connection resolves but remains correctly blocked by water
until a future traversal system supplies Surf.

M3 adds source-controlled, provenance-cited Crystal behavior for the
introduction, profile naming, New Bark Town, Elm's Lab, all three starter
choices, Elm's phone registration, and the aide's Potion handoff. Native
coroutine commands now cover state, dialogue requests, actor movement,
following, emotes, map/object changes, battle requests, audio events, party
grants, inventory grants, and phone contacts. Coverage reports compare these
definitions with decoded static map interactions.

The pre-M5 presentation closure adds a reusable controller over those service
requests. It draws dialogue boxes, selectable choices, a clock editor, preset
names, and a custom on-screen keyboard without coupling script behavior to
LÖVE. The visible ROM preview runs the introduction before entering the world
and carries its `ScriptState` forward. A map presentation adapter dispatches
New Bark and Elm's Lab object/sign interactions and begins Elm's scene when
the lab is entered.

M5 begins with `GameSession`, the persistent owner for one running game. It
binds an exact ROM profile to script state, party, inventory, phone contacts,
clock, money, player location, and Pokédex seen/caught sets. Its schema-1
snapshot is data-only and detached from live services. M5-011 will add atomic
filesystem persistence around this contract; M5-001 does not write saves.
World and map-script presentation now share the session-owned services rather
than creating progression state that disappears between maps.

M5-002 adds a profile-owned text extraction manifest for 55 introduction,
New Bark, and Elm's Lab records. `CrystalTextData` reads those records from the
verified ROM into normalized glyph, layout, and substitution tokens, then
releases the ROM with the rest of the preview importer. `RomTextProvider`
resolves player/species values and creates two-line pages for the existing
presentation controller. Source control contains symbol metadata only; exact
dialogue exists solely in the player's ROM and private runtime/cache data.

M5-003 adds a `BattleSceneState` and `BattlePresentation` adapter over the
presentation-independent M4 session. The adapter consumes semantic battle
events and exposes HUD, messages, root commands, moves/PP, party switches,
catching, escape attempts, and terminal acknowledgement. It does not mutate
the deterministic battle core outside its public session API. The scene has a
standalone ROM-backed developer preview.

M5-004 adds the dispatch boundary. `BattleRequestFactory` adapts
`GameSession.party` members and semantic script requests into ROM-backed
instances without exposing ROM offsets to gameplay code. `BattleBridge` pushes
the scene on the application stack, commits HP/EXP/DV/move/PP and Pokédex
changes, pops back to the world, then resolves the original coroutine wait.
`MapPresentationRuntime` dispatches each active `BattleService` request once.

M4 adds normalized species, move, item, and trainer records; Gen 2 integer
stats, DVs, gender, shiny state, and Hidden Power; deterministic battle state,
action ordering, switching, damage, status, effect dispatch, AI, catching,
experience, and move learning; and a presentation-independent battle session.
Battle completion now settles player wins, opponent wins, draws, catches, and
forced party replacements. A compact battle-data manifest locates the 251
species and 251 move records decoded from a verified Crystal ROM. The
player-ROM-gated M4 route completes deterministic first-rival and Route 29
wild fixtures with terminal outcomes and experience awards.

The project does not yet contain the first-launch file picker or
importer-screen wiring. M3's text, choice, clock, and naming services are
connected to visible LÖVE UI, and the current 55-record slice now uses exact
ROM-owned dialogue. The battle simulation now has a visible standalone scene,
but broader move-effect coverage, held items, weather, world dispatch, saves,
audio playback, and campaign progression remain future work. Import, world,
event, presentation, and battle acceptance are exercised through fixtures and
local player-ROM-gated verification commands.
