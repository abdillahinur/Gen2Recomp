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

The repository has completed **M2: New Bark world slice**, including
end-to-end verification with canonical English Crystal v1.1. The project
currently contains:

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
- a verified New Bark slice containing eight extracted maps, four tilesets,
  and sixteen referenced overworld sprites;
- headless unit tests and CI;
- architecture, milestone, and backlog documentation.

There is no first-launch ROM picker or application importer screen yet. The
developer preview is a traversable world slice, not the complete game:
dialogue, events, story progression, battles, menus, saves, audio, and most
maps remain future milestones.

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
./scripts/run-m2.ps1 -RomPath "D:\path\to\your\ROM"
```

Use the arrow keys to move. The preview does not write the ROM or decoded
content into the repository.

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

## Project direction

- [Project plan](docs/PROJECT_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Milestones](docs/MILESTONES.md)
- [Backlog](docs/BACKLOG.md)
- [Private cache format](docs/CACHE_FORMAT.md)
- [Reference-data generation](docs/REFERENCE_DATA.md)
- [Content policy](docs/CONTENT_POLICY.md)

## ROM support

The identity layer recognizes these canonical English Crystal ROMs:

```text
v1.0  f4cd194bdee0d04ca4eac29e09b8e4e9d818c133
v1.1  f2f52230b536214ef7c9924f483392993e226cfb
```

ROMs, saves, generated caches, screenshots containing extracted game content,
and other private game data must never be committed.
