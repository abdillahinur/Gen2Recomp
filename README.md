# Gen2Recomp

Gen2Recomp is a native LÖVE2D recreation of the English releases of Pokémon
Gold, Silver, and Crystal. The engine and map behavior are hand-written Lua;
game data and graphics are decoded from a ROM supplied by the player.

The project does not emulate Game Boy hardware, execute ROM code, transpile
assembly, or distribute ROMs or pre-extracted game content. The importer
verifies a player-supplied ROM, decodes static content required by the native
engine into a private cache, releases the ROM, and uses only that cache during
normal play. A future first-boot UI will invoke this importer.

## Current status

The repository has completed M5's functional first-badge route and has
**reopened M5 for live cartridge fidelity** after hands-on preview testing
exposed placeholder presentation and audio. Canonical English Crystal v1.1
continues to pass the functional M1–M5 gates. The project currently contains:

- a minimal LÖVE 11.x application;
- a deterministic 60 Hz fixed-step loop;
- input and state-stack foundations;
- exact Crystal US v1.0 and v1.1 profile identification;
- a bounds-checked reader for absolute and banked ROM addresses;
- a streaming, LuaJIT-compatible SHA-1 implementation;
- transactional private caches with cancellation and recovery;
- a pinned RGBDS symbol-manifest generator;
- normalized Crystal font, charmap, species, tileset, map, event-metadata,
  collision, sprite, roof, and palette extraction;
- monotonic import progress, a structural report, and raw-ROM retention guard;
- a native 160×144 nearest-neighbor renderer with CGB morning, day, and night
  palettes;
- a generic map grid, camera, player movement/facing, collision, objects,
  connections, and reciprocal warps;
- a ROM-backed first-badge world corridor containing 29 maps across New Bark,
  Cherrygrove, Routes 29-32/36, and Violet City, with ten referenced
  tilesets and 32 ordinary overworld sprites;
- player-ROM-backed morning/day/night grass and water encounter tables for
  eight maps in that corridor, with native slot weights and step cooldown;
- player-ROM-backed trainer parties, native trainer sight lines, visible shock
  and approach behavior, battle dispatch, and persistent defeat flags;
- a native coroutine script runner with flags, scenes, variables, text,
  choices, actor movement, objects, maps, battle requests, and audio events;
- provenance-cited Crystal Lua behavior for the introduction, naming,
  New Bark Town, Elm's Lab, all three starter choices, Elm's phone
  registration, and the aide's Potion handoff;
- party, inventory, phone, clock, naming, dialogue, and coverage-report
  services for the M3 behavior slice;
- ROM-font dialogue boxes and an exact ROM-owned gender prompt, plus visible
  clock setup, naming, New Bark interactions, and Elm's Lab presentation;
- runtime decoding of 109 ROM-owned introduction, New Bark, Elm's Lab,
  Cherrygrove, route, and Violet text records, with two-line pagination and
  player/species substitutions;
- a visible native battle scene with HP HUDs, messages, Fight, Pack, Pokémon,
  Run, move selection, party switching, catching, and terminal outcomes;
- a stack-based world/script battle bridge that returns outcomes to suspended
  Lua behavior and persists HP, EXP, DVs, moves, PP, and Pokédex discoveries;
- source-controlled Route 29–32/36, Cherrygrove, Violet, Mr. Pokémon, academy,
  gate, house, item, fruit, Map Card, Mystery Egg, Pokédex, rival, and
  pre-badge boundary behavior;
- a profile-bound persistent game-session contract for script, party,
  inventory, phone, clock, money, player-location, and Pokédex state;
- a visible Start menu with persistent Pack quantities, party summaries, and a
  complete ROM-named 251-entry Pokédex with seen/caught gating;
- visible Cherrygrove/Violet Center healing, mart buying/selling, and persistent
  PC Pokémon storage;
- versioned, checksummed native saves with atomic replacement, backup recovery,
  exact-ROM profile binding, player-location restore, and elapsed-time RTC;
- audible placeholder map/battle cues, menu SFX, and species cry scheduling
  through a LÖVE audio sink; exact ROM channel-program playback is in progress;
- complete Violet Gym interaction behavior, ROM-backed Falkner battle, Zephyr
  Badge and TM31 rewards, and Route 32 progression unlock;
- normalized battle records and Gen 2 Pokémon instances with integer stats,
  DVs, gender, shiny state, Hidden Power, and growth curves;
- deterministic battle turns, switching and forced replacements, damage,
  accuracy, critical hits, type effects, major/volatile status, effect
  dispatch, and trainer AI foundations;
- catching, experience, level-up, move learning, and terminal battle outcomes;
- a player-ROM-gated first-rival and Route 29 wild-battle verification route
  using all 251 species and 251 moves decoded from Crystal;
- headless unit tests and CI;
- architecture, milestone, and backlog documentation.

There is no first-launch ROM picker or application importer screen yet. With a
ROM path, the developer preview now visibly runs M3's introduction, gender
choice, clock setup, ROM-owned dialogue, and on-screen naming before entering
the world. New Bark NPC/sign interactions and Elm's Lab scene use the same
visible, paginated presentation controller. Semantic labels remain only as a
fallback for dialogue outside the current 109-record extraction manifest. The
M4 simulation now has a standalone visible battle preview, and M5-004 connects
world/script requests to it. M5-005 expands the traversable ROM-backed world
from New Bark through Cherrygrove and Violet City. M5-006 now starts visible
wild battles from eligible steps using the session clock. M5-007 adds
ROM-backed trainer parties and visible overworld trainer challenges. M5-008
adds native route/city events through Violet and expands exact ROM-owned text
to 96 records. M5-009 adds the visible Pack, party, and Pokédex field menu.
M5-010 adds visible Pokémon Center, mart, and PC flows.
M5-011 adds visible native saving and automatic profile-bound restore.
M5-012 connects introduction, world, battle, and menu audio playback.
M5-013 completes Falkner's Gym and first-badge progression.
M5-014 closes the functional slice with a ROM-gated
introduction-to-Zephyr-Badge route, 109 decoded dialogue records, and verified
save/reload. M5-015 begins the reopened live-fidelity pass with the decoded
Crystal font and exact gender-screen text/menu geometry. Faithful professor
art/timing, object-dialogue auditing, and ROM channel audio remain required
before M5 can be called complete again.

## Final deliverable

The release target is a normal native desktop application. A Windows release
will contain `Gen2Recomp.exe` and the required LÖVE runtime libraries, typically
distributed as a ZIP or installer. Equivalent macOS and Linux application
packages may follow.

On first launch, the executable will ask the player for a supported Gold,
Silver, or Crystal ROM, verify it, create a private content cache, release the
ROM, and start the native Lua game. Later launches will use that cache without
asking for the ROM again.

The distributed application will contain no ROM or pre-extracted Pokémon game
content.

## Running

Install [LÖVE 11.x](https://love2d.org/) and run:

```sh
love .
```

That command currently opens the content-free bootstrap. To import a supported
ROM into memory and run the New Bark developer preview:

```powershell
./scripts/run-crystal-preview.ps1 -RomPath "D:\path\to\your\ROM"
```

Add `-Fresh` to ignore an existing native save for that run and begin at the
gender screen without deleting or moving the save:

```powershell
./scripts/run-crystal-preview.ps1 -RomPath "D:\path\to\your\ROM" -Fresh
```

Use the arrow keys to move. The preview does not write the ROM or decoded
content into the repository. Use Z, Enter, or Space to confirm; X or Backspace
returns from custom naming to the name choices. Face an NPC, object, or sign
and press Confirm to run its available M3 interaction.

## Testing

The test suite is compatible with Lua 5.1 and LuaJIT:

```powershell
./scripts/test.ps1
```

or:

```sh
./scripts/test.sh
```

To run the LÖVE bootstrap briefly and exit automatically:

```powershell
./scripts/smoke.ps1
```

To repeat M1's end-to-end acceptance check with your own supported canonical
English Crystal ROM:

```powershell
./scripts/verify-crystal-import.ps1 -RomPath "D:\path\to\your\ROM"
```

This verifies and imports into an in-memory cache, prints structural counts,
and exits without writing the ROM or decoded content into the repository.

To run M2's world-data and native-runtime acceptance check:

```powershell
./scripts/verify-crystal-world.ps1 -RomPath "D:\path\to\your\ROM"
```

This checks map, tileset, sprite, collision, connection, warp, and tile
references; exercises every New Bark building warp in both directions; crosses
the walkable Route 29 boundary; confirms Route 27 is correctly blocked by
water on foot; and hashes distinct morning, day, and night 160×144 frames.

To compare source-controlled Lua behavior coverage with the static map
interactions decoded from a supported ROM:

```powershell
./scripts/report-crystal-coverage.ps1 -RomPath "D:\path\to\your\ROM"
```

The report separates scripted maps, callbacks, scenes, coordinate events,
background events, and object interactions. Unimplemented maps and partial
vertical-slice coverage remain visible.

To run M3's introduction, naming, Elm meeting, starter, phone, and Potion
acceptance route against canonical English Crystal v1.1:

```powershell
./scripts/verify-crystal-events.ps1 -RomPath "D:\path\to\your\ROM"
```

This executes the source-controlled Lua behavior against decoded real map and
object data, and verifies visible presentation models for dialogue, choices,
clock setup, and naming, without writing ROM content into the repository.

To verify M5-002's ROM-owned text catalog and visible pagination:

```powershell
./scripts/verify-crystal-text.ps1 -RomPath "D:\path\to\your\ROM"
```

This decodes the 109 currently mapped records, validates substitutions and
two-line pages, and audits the normalized result for retained raw ROM ranges.

To run M4's deterministic first-rival and ordinary wild-battle gates:

```powershell
./scripts/verify-crystal-battles.ps1 -RomPath "D:\path\to\your\ROM"
```

This decodes normalized species and move records directly from the supplied
ROM, completes both headless battle fixtures, verifies their outcomes and
experience awards, and retains no raw ROM ranges.

To open M5-003's standalone Route 29 battle scene:

```powershell
./scripts/run-battle-preview.ps1 -RomPath "D:\path\to\your\ROM"
```

To drive that visible presentation model to a verified terminal result:

```powershell
./scripts/verify-crystal-battle-ui.ps1 -RomPath "D:\path\to\your\ROM"
```

To verify M5-004's world-stack bridge and persistent battle result:

```powershell
./scripts/verify-crystal-battle-bridge.ps1 -RomPath "D:\path\to\your\ROM"
```

To verify M5-005's ROM-backed New Bark-to-Violet world corridor:

```powershell
./scripts/verify-crystal-violet-world.ps1 -RomPath "D:\path\to\your\ROM"
```

This checks all 29 selected maps and ten tilesets, the bidirectional route
connections, reciprocal city-building warps, and every rendered tile
reference. Sprout Tower remains an explicit outbound boundary for a later
world expansion.

To verify M5-006's time-based wild encounter selection and battle dispatch:

```powershell
./scripts/verify-crystal-encounters.ps1 -RomPath "D:\path\to\your\ROM"
```

This audits the ROM-backed Johto tables, morning/night Route 29 differences,
encounter grass, five-step cooldown, and creation of a native battle through
the existing bridge.

To verify M5-007's trainer-party decoding, sight, approach, and persistence:

```powershell
./scripts/verify-crystal-trainers.ps1 -RomPath "D:\path\to\your\ROM"
```

This locates Youngster Joey and the Violet Gym trainers in the supplied ROM,
executes Joey's real Route 30 sight and approach path, creates his native
battle party, and verifies that victory prevents a repeat challenge.

To verify M5-008's native route and city behavior:

```powershell
./scripts/verify-crystal-violet-events.ps1 -RomPath "D:\path\to\your\ROM"
```

This checks 19 scripted maps against decoded event metadata, executes the
Mystery Egg and Pokédex meeting, guide gift, rival battle gate, and Route 32
pre-badge boundary on the real ROM-backed world, and verifies the 109-record
dialogue catalog.

To verify M5-009's Pack, party, and Pokédex field menu:

```powershell
./scripts/verify-crystal-field-menu.ps1 -RomPath "D:\path\to\your\ROM"
```

This checks persistent Pack quantities and party summaries, the story-gated
Pokédex, all 251 ROM-derived species names, unseen-name hiding, and seen/caught
totals.

To verify M5-010's Center, mart, and PC systems:

```powershell
./scripts/verify-crystal-facilities.ps1 -RomPath "D:\path\to\your\ROM"
```

This validates the decoded facility maps and nurse/clerk objects, then drives
healing, a visible purchase, PC deposit, and snapshot restoration.

To verify M5-011's native-save and RTC contract:

```powershell
./scripts/verify-crystal-save.ps1 -RomPath "D:\path\to\your\ROM"
```

This verifies the save envelope against the supplied ROM revision, restores
progress and world location, advances the RTC across midnight, and rejects a
different ROM profile.

To verify M5-012's music, SFX, and cry scheduling:

```powershell
./scripts/verify-crystal-audio.ps1 -RomPath "D:\path\to\your\ROM"
```

This checks ordered one-shot scheduling and a cry keyed by a species identity
decoded from the supplied ROM. LÖVE smoke verification covers the playback
sink itself.

To verify M5-013's Falkner and badge progression:

```powershell
./scripts/verify-crystal-falkner.ps1 -RomPath "D:\path\to\your\ROM"
```

This verifies Falkner's exact ROM-backed party, native battle construction,
the winning reward path, Zephyr Badge persistence, and TM31.

To run M5's complete introduction-to-first-badge acceptance gate:

```powershell
./scripts/verify-crystal-vertical-slice.ps1 -RomPath "D:\path\to\your\ROM"
```

This executes the ordered story services from introduction through Falkner,
rejects semantic fallback for all 37 required dialogue requests, constructs
the native leader battle, and verifies the completed badge state after a
versioned save/reload.

## Project direction

- [Project plan](docs/PROJECT_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Milestones](docs/MILESTONES.md)
- [Backlog](docs/BACKLOG.md)
- [Private cache format](docs/CACHE_FORMAT.md)
- [Reference-data generation](docs/REFERENCE_DATA.md)
- [Battle engine](docs/BATTLE_ENGINE.md)
- [M5 Violet City slice](docs/M5_VERTICAL_SLICE.md)
- [Content policy](docs/CONTENT_POLICY.md)

## ROM support

The identity layer recognizes these canonical English Crystal ROMs:

```text
v1.0  f4cd194bdee0d04ca4eac29e09b8e4e9d818c133
v1.1  f2f52230b536214ef7c9924f483392993e226cfb
```

ROMs, saves, generated caches, screenshots containing extracted game content,
and other private game data must never be committed.
