# Project plan

## Objective

Create a faithful native LÖVE2D recreation of the canonical English releases
of Pokémon Gold, Silver, and Crystal, delivered as a normal desktop
application and using only a verified player-supplied ROM as the source of
game content.

The first behavior implementation target is Crystal US v1.0. The M1 importer
supports separate immutable English v1.0 and v1.1 ROM profiles, but neither
version will be declared playable until Crystal's core campaign is stable.

A Windows release will provide `Gen2Recomp.exe` with the required LÖVE runtime
libraries in a ZIP or installer. First launch imports a verified ROM into a
private cache; subsequent launches run from that cache. Release packages never
contain a ROM or pre-extracted game content.

## Product principles

1. **No bundled game content.** The repository and packaged application contain
   engine code and extraction metadata only.
2. **Faithfulness first.** Establish cartridge behavior before adding optional
   fixes, modern rules, expanded views, or graphical effects.
3. **One native engine.** Version variation belongs in profiles, data, and
   named rules.
4. **Hand-write behavior.** The ROM supplies static data and assets; engine,
   battle, world, and map/event behavior are rewritten in Lua.
5. **Deterministic core.** Battle, world, RNG, and RTC behavior must be
   repeatable under tests.
6. **Vertical slices.** Complete and verify narrow end-to-end routes before
   broad content expansion.
7. **Recoverable data.** Import and save operations are transactional and
   maintain backups.

## Implementation order

### Foundation

Build the LÖVE application shell, fixed-step loop, input, state management,
test runner, CI, policies, and version-profile boundary.

### Import pipeline

Implement ROM reading, exact hash identification, immutable manifests,
transactional caches, extraction primitives, and validation reports.

Developer tools may consume locally built RGBDS symbol/map output from pinned
`pokecrystal` and `pokegold` revisions. The packaged application must not
download or require a disassembly.

### World vertical slice

Extract and render New Bark Town with correct CGB palettes, collision,
movement, objects, connections, and warps. This M2 slice is complete for the
canonical English Crystal profiles and verified locally with v1.1; it is a
traversable engine/data slice, not campaign gameplay.

### Hand-written event slice

Create source-controlled Lua map scripts and a reusable coroutine command API.
Hand-port the introduction, naming, Elm sequence, and starter selection from
the documented reference behavior. Static map structures and text may be
decoded from the verified ROM, but original event bytecode is not executed or
translated. This M3 behavior slice is complete and verified locally against
canonical English Crystal v1.1 map and object data. Presentation wiring for
the developer preview is now complete for semantic dialogue, choices, clock
setup, and on-screen naming. Exact dialogue wording remains ROM-owned static
content and will replace the semantic preview labels when its importer lands.

### Pokémon and battle vertical slice

Implement the Gen 2 domain model and a presentation-independent deterministic
battle simulation. Use the first rival and wild encounters as the initial
end-to-end battle gates. This M4 simulation slice is complete and verified
locally against species and move data decoded from canonical English Crystal
v1.1. Visible battle-scene and command-menu wiring belongs to the next
application-integration slice.

### Systems and content expansion

Expand one verified gameplay route at a time through Violet City, Johto,
Elite Four, Kanto, Red, and Crystal-exclusive content. Implement phone, RTC,
breeding, contests, minigames, and Battle Tower when the route reaches them.

### Additional versions

Crystal v1.1 identity and the M1/M2/M3/M4 slices are already supported. Extend
both Crystal revisions together as behavior grows, then add Gold and Silver
profiles. Differences must be expressed as data/profile capabilities wherever
possible.

### Hardening

Complete audio parity, save recovery, packaging, performance testing,
documentation, and optional cartridge-save interoperability.

## Major workstreams

### Import and tooling

- ROM abstraction with bank/address validation.
- SHA-1 and cartridge-header verification.
- Profile registry keyed by exact hashes.
- Manifest generation from pinned symbols.
- Graphics and compression decoding.
- Text and static map-structure decoding.
- Audio-program decoding.
- Transactional cache and validation.
- Forbidden-content scanner.

### Native engine

- Fixed 60 Hz simulation.
- Action-based input and controllers.
- State stack and service ownership.
- 160×144 CGB renderer.
- Map/world simulation.
- Coroutine scheduler for hand-written Lua map scripts.
- UI and menus.
- Audio synthesizer and mixer.

### Game behavior

- Gen 2 species, moves, items, stats, and evolution.
- DVs, gender, shiny state, Hidden Power, friendship, Pokérus, and mail.
- Battles, move effects, held items, weather, AI, catching, and experience.
- RTC, day/night, phone, radio, daycare, breeding, contests, and Battle Tower.
- Hand-written Lua scripts for the main campaign and postgame.

### Quality

- Pure unit tests.
- Synthetic importer fixtures.
- Local ROM-gated structural tests.
- Differential scenarios against a scriptable reference emulator.
- Automated campaign drivers.
- Map, scene, callback, and interaction coverage checklists.
- Save migration and corruption recovery tests.
- Importer fuzz and malformed-input tests.

## Version targets

| Game | SHA-1 | Plan |
| --- | --- | --- |
| Crystal US/EU v1.0 | `f4cd194bdee0d04ca4eac29e09b8e4e9d818c133` | M1 profile; primary behavior target |
| Crystal US/EU v1.1 | `f2f52230b536214ef7c9924f483392993e226cfb` | M1–M4 profile; ROM-gated import, world, event, and battle slices verified |
| Gold US/EU | `d8b8a3600a465308c9953dfa04f0081c05bdcb94` | After Crystal |
| Silver US/EU | `49b163f7e57702bc939d642a18f591de55d92dae` | With Gold |

Other languages, Australian Crystal, debug builds, Virtual Console variants,
and ROM hacks are out of initial scope.

## Initial non-goals

- Game Boy CPU or hardware emulation.
- Executing or translating original assembly or event bytecode.
- Japanese Mobile Adapter functionality.
- Original hardware link compatibility.
- Online play and Time Capsule.
- Mystery Gift infrared emulation.
- Game Boy Printer support.
- Mods and save editor.
- Mobile/handheld packages.
- HD/3D graphics.
- Hardware-timing and arbitrary-memory-corruption glitches.

## Rough scale

The planning assumption for a faithful all-version release is roughly:

- 24–36 months for an experienced solo developer working full-time;
- 3–6 years at hobby pace;
- 12–24 months for a small experienced team after tooling and ownership
  boundaries stabilize.

These ranges are not deadlines. Later estimates should be recalibrated from
measured milestone throughput and coverage data.

## Definition of a supported release

A ROM profile is supported only when:

- its exact canonical hash imports successfully;
- import validation has no unresolved references;
- every required map, scene, callback, interaction, and story gate has a
  hand-written Lua implementation;
- the complete campaign and postgame route pass;
- battle and RTC behavior have targeted differential coverage;
- saves survive migration, interruption, and recovery tests;
- audio and required UI are present;
- the distributed package contains no ROM or pre-extracted game content.
