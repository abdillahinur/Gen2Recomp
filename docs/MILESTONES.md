# Milestones

Each milestone has an observable exit gate. Dates are intentionally omitted
until development velocity is measured.

## M0 — Foundation

Deliver:

- Git repository and project policies;
- LÖVE 11.x bootstrap;
- deterministic fixed-step loop;
- input and state-stack abstractions;
- initial ROM-profile interface;
- Lua 5.1-compatible unit tests and CI;
- architecture and planning documentation.

Exit gate:

- source tree is reproducible and contains no game content;
- headless tests pass in CI;
- `love .` opens the bootstrap application.

## M1 — Verified Crystal importer

Deliver:

- bank-aware ROM reader;
- streaming SHA-1 validation;
- Crystal US v1.0 and v1.1 identification;
- transactional private cache;
- symbol-manifest generator;
- extraction of constants, font, charmap, species, and one tileset;
- structural validation and import report.

Exit gate:

- [x] A canonical Crystal ROM imports successfully. English v1.1 was verified
  locally through the player-ROM-gated command:
  `./scripts/verify-crystal-import.ps1 -RomPath "<path>"`.
- [x] Modified/unknown ROMs are rejected.
- [x] Import failure never damages an existing cache.
- [x] The cache does not contain a copy of the ROM.

## M2 — New Bark world slice

Deliver:

- CGB tile and palette rendering;
- New Bark Town map extraction;
- map collision, player movement, camera, and warps;
- object sprites and time-of-day palette provider;
- deterministic world tests.

Exit gate:

- [x] New Bark Town renders and can be traversed with correct collision and
  warps. Canonical English Crystal v1.1 was verified through
  `./scripts/verify-crystal-world.ps1 -RomPath "<path>"`, including all four
  building warp round trips, the walkable Route 29 boundary, Route 27's
  correctly terrain-blocked water boundary, and distinct morning/day/night
  frames.

## M3 — Hand-written event slice

Deliver:

- `data/scripts/` conventions and source-provenance rules;
- hand-written map scenes, callbacks, coord events, BG interactions, and object
  interactions for the vertical slice;
- coroutine runner for native Lua commands;
- reusable dialogue, flag, scene, battle, movement, and object commands;
- text boxes, choices, naming, flags, and movement commands;
- visible presentation for dialogue requests, choices, clock setup, and
  on-screen naming.

Exit gate:

- [x] The introduction, player naming, Elm sequence, all three starter
  branches, Elm's phone registration, and the aide's Potion handoff execute
  entirely through source-controlled Lua behavior with reference citations.
  Canonical English Crystal v1.1 was verified through
  `./scripts/verify-crystal-events.ps1 -RomPath "<path>"`. The same gate now
  verifies presentation models for text, choices, clock setup, and naming.

The ROM preview starts with the visible introduction, carries its script state
into the world, opens New Bark NPC/sign interactions with Confirm, and starts
Elm's meeting scene on entering the lab.

## M4 — Battle slice

Deliver:

- Gen 2 Pokémon instance/stat model;
- deterministic battle state and turn resolver;
- core damage, accuracy, critical, status, switching, and AI behavior;
- presentation-independent battle-session API;
- experience, level-up, move learning, and basic catching.

Exit gate:

- [x] First rival and ordinary wild battles complete with deterministic,
  verified outcomes. Canonical English Crystal v1.1 was verified through
  `./scripts/verify-crystal-battles.ps1 -RomPath "<path>"`; both fixtures use
  species and move records decoded from the supplied ROM.

M5-003 now supplies visible battle presentation. M4's exit gate continues to
cover the native simulation and its session boundary.

## M5 — Violet City vertical slice

Deliver:

- one persistent runtime game session owning script, party, inventory, phone,
  clock, Pokédex, money, and player-location state;
- exact ROM-owned dialogue decoding and paginated presentation;
- encounters by time period;
- trainers and trainer sight;
- Pack, party, Pokémon Center, mart, PC, and Pokédex foundations;
- Falkner gym flow;
- reliable save/load and RTC persistence;
- music, SFX, and cries for the slice.

Exit gate:

- a new save can play from the introduction through the first badge.

Detailed checkpoint order and the native session/save boundary are defined in
[`M5_VERTICAL_SLICE.md`](M5_VERTICAL_SLICE.md).

Completed checkpoints:

- [x] M5-001 persistent game-session contract.
- [x] M5-002 55-record ROM-owned dialogue catalog and visible pagination.
- [x] M5-003 visible battle scene, messages, and command menus.
- [x] M5-004 world/script battle dispatch and persistent result bridge.
- [x] M5-005 ROM-backed New Bark-to-Violet world corridor.
- [x] M5-006 time-based wild encounter selection and battle dispatch.
- [x] M5-007 trainer sight, approach, and ROM-backed trainer battles.
- [x] M5-008 Route, Cherrygrove, and Violet native event behavior.
- [x] M5-009 visible Pack, party, and ROM-backed Pokédex presentation.
- [x] M5-010 visible Pokémon Center, mart, and PC systems.

## M6 — Johto campaign

Exit gate:

- all eight Johto badges, Team Rocket story, Elite Four, credits, and required
  side systems are completable through an automated route.

## M7 — Kanto and final battle

Exit gate:

- Kanto progression, all Kanto badges, Mt. Silver, and Red are completable.

## M8 — Crystal completion

Exit gate:

- Crystal-exclusive story, animated front sprites, Battle Tower, phone/RTC
  events, breeding, contests, minigames, and remaining side content are
  covered; the map/scene/interaction coverage checklist is complete.

## M9 — Gold and Silver

Exit gate:

- canonical English Gold and Silver ROMs import into independent caches;
- version-specific story, data, maps, encounters, graphics, and rules work;
- both games pass the full automated campaign route.

## M10 — Release hardening

Deliver:

- packaging for supported desktop platforms;
- cache repair and save recovery UX;
- accessibility and controller configuration;
- performance and long-session testing;
- optional cartridge-save import/export;
- complete user and contributor documentation.

Link play, Time Capsule interoperability, modding, mobile ports, and graphical
enhancements require separate post-core milestones unless reprioritized.
