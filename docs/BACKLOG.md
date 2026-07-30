# Backlog

Backlog IDs are stable planning references, not issue tracker numbers.

## M0 — Foundation

- [x] `M0-001` Establish repository content and provenance policy.
- [x] `M0-002` Document architecture, milestones, and project plan.
- [x] `M0-003` Add LÖVE 11.x application bootstrap.
- [x] `M0-004` Add deterministic fixed-step scheduler.
- [x] `M0-005` Add action-based keyboard input.
- [x] `M0-006` Add stack-based application states.
- [x] `M0-007` Define initial immutable ROM-profile interface.
- [x] `M0-008` Add Lua 5.1-compatible headless tests.
- [x] `M0-009` Add CI test workflow.
- [x] `M0-010` Run tests locally under LuaJIT/LÖVE.
- [x] `M0-011` Confirm the bootstrap window on Windows.
- [x] `M0-012` Add automated forbidden-content scan.

## M1 — Importer

- [x] `M1-001` Implement bounds-checked byte/word/bank ROM reader.
- [x] `M1-002` Implement streaming SHA-1.
- [x] `M1-003` Parse and validate cartridge headers.
- [x] `M1-004` Match ROMs through the profile registry.
- [x] `M1-005` Design cache manifest and ownership metadata.
- [x] `M1-006` Implement temporary cache and atomic promotion.
- [x] `M1-007` Add cancellation and failure recovery.
- [x] `M1-008` Generate Crystal symbols from pinned RGBDS output.
- [x] `M1-009` Decode Crystal font and charmap.
- [x] `M1-010` Decode species/base-stat records.
- [x] `M1-011` Decode one tileset and palette set.
- [x] `M1-012` Add extraction progress and structural report.
- [x] `M1-013` Test that large raw ROM ranges are not retained.
- [x] `M1-014` Add malformed and truncated ROM fixtures.
- [x] `M1-015` Add and verify the canonical English Crystal v1.1 profile.

## M2 — New Bark world

- [x] `M2-001` Create 160×144 nearest-neighbor canvas.
- [x] `M2-002` Decode CGB 15-bit palettes.
- [x] `M2-003` Decode tiles, attributes, metatiles, and map blocks.
- [x] `M2-004` Extract map groups and headers.
- [x] `M2-005` Extract collision and directional permissions.
- [x] `M2-006` Render New Bark Town.
- [x] `M2-007` Add player grid movement and facing.
- [x] `M2-008` Add objects and sprite palettes.
- [x] `M2-009` Add camera, map connections, and warps.
- [x] `M2-010` Add injectable time-of-day palette selection.

## M3 — Events

- [x] `M3-001` Define `data/scripts/` conventions and provenance requirements.
- [x] `M3-002` Implement coroutine runner for hand-written Lua commands.
- [x] `M3-003` Implement flags, scenes, variables, text, and choices.
- [x] `M3-004` Implement movement, facing, following, and emotes.
- [x] `M3-005` Implement battles, warps, objects, map changes, and audio commands.
- [x] `M3-006` Hand-write introduction and naming behavior in Lua.
- [x] `M3-007` Hand-write New Bark Town and Elm's Lab behavior in Lua.
- [x] `M3-008` Create map/scene/callback/interaction coverage reports.
- [x] `M3-009` Complete introduction and naming flow.
- [x] `M3-010` Complete Elm and starter sequence.

## M4 — Pokémon and battles

- [x] `M4-001` Define normalized species, move, item, and trainer records.
- [x] `M4-002` Implement Gen 2 Pokémon instances and integer stat calculations.
- [x] `M4-003` Implement DVs, gender, shiny state, and Hidden Power.
- [x] `M4-004` Implement deterministic battle state and RNG injection.
- [x] `M4-005` Implement action selection, priority, speed, and switching.
- [x] `M4-006` Implement damage, accuracy, critical hits, and type effects.
- [x] `M4-007` Implement major and volatile status framework.
- [x] `M4-008` Implement effect-command registry.
- [x] `M4-009` Implement trainer AI foundations.
- [ ] `M4-010` Implement catching, experience, level-up, and move learning.
- [ ] `M4-011` Complete first rival and wild battle gates.

## Cross-cutting risks

- [ ] `RISK-001` Inventory complex engine routines required by each map and
  assign each one a named native Lua implementation.
- [ ] `RISK-002` Define differential-test state snapshots.
- [ ] `RISK-003` Define RTC behavior for timezone/DST changes.
- [ ] `RISK-004` Design native-save schema and migrations before M5.
- [ ] `RISK-005` Establish source provenance tracking for adapted code.
- [ ] `RISK-006` Re-estimate schedule after the Violet City slice.
