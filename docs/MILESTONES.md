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

- New Bark Town renders and can be traversed with correct collision and warps.

## M3 — Hand-written event slice

Deliver:

- `data/scripts/` conventions and source-provenance rules;
- hand-written map scenes, callbacks, coord events, BG interactions, and object
  interactions for the vertical slice;
- coroutine runner for native Lua commands;
- reusable dialogue, flag, scene, battle, movement, and object commands;
- text boxes, choices, naming, flags, and movement commands.

Exit gate:

- the introduction, player naming, Elm sequence, and starter selection execute
  entirely through source-controlled Lua behavior, with reference citations.

## M4 — Battle slice

Deliver:

- Gen 2 Pokémon instance/stat model;
- deterministic battle state and turn resolver;
- core damage, accuracy, critical, status, switching, and AI behavior;
- battle UI;
- experience, level-up, move learning, and basic catching.

Exit gate:

- first rival and ordinary wild battles complete with verified outcomes.

## M5 — Violet City vertical slice

Deliver:

- encounters by time period;
- trainers and trainer sight;
- Pack, party, Pokémon Center, mart, PC, and Pokédex foundations;
- Falkner gym flow;
- reliable save/load and RTC persistence;
- music, SFX, and cries for the slice.

Exit gate:

- a new save can play from the introduction through the first badge.

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
