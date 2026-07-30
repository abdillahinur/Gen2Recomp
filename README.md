# Gen2Recomp

Gen2Recomp is a native LÖVE2D recreation of the English releases of Pokémon
Gold, Silver, and Crystal. The engine and map behavior are hand-written Lua;
game data and graphics are decoded from a ROM supplied by the player.

The project does not emulate Game Boy hardware, execute ROM code, transpile
assembly, or distribute ROMs or pre-extracted game content. A future
first-boot importer will verify a player-supplied ROM, decode static content
required by the native engine into a private cache, release the ROM, and use
only that cache during normal play.

## Current status

The repository has completed **M0: Foundation** and started **M1: Verified
Crystal importer**. It currently contains:

- a minimal LÖVE 11.x application;
- a deterministic 60 Hz fixed-step loop;
- input and state-stack foundations;
- an initial Crystal US v1.0 profile boundary;
- a bounds-checked reader for absolute and banked ROM addresses;
- a streaming, LuaJIT-compatible SHA-1 implementation;
- cartridge-header parsing and exact profile identification;
- a versioned private-cache manifest and ownership contract;
- headless unit tests and CI;
- architecture, milestone, and backlog documentation.

There is no cache-building importer, first-launch ROM picker, or playable game
yet.

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

## Project direction

- [Project plan](docs/PROJECT_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Milestones](docs/MILESTONES.md)
- [Backlog](docs/BACKLOG.md)
- [Private cache format](docs/CACHE_FORMAT.md)
- [Content policy](docs/CONTENT_POLICY.md)

## ROM support

The identity layer recognizes the canonical English Crystal v1.0 ROM with
SHA-1:

```text
f4cd194bdee0d04ca4eac29e09b8e4e9d818c133
```

ROMs, saves, generated caches, screenshots containing extracted game content,
and other private game data must never be committed.
