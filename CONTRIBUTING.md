# Contributing

Gen2Recomp is currently establishing its foundations. Contributions should be
small, testable, and tied to an item in `docs/BACKLOG.md`.

## Non-negotiable content rules

- Never commit a ROM, cartridge save, or ROM fragment.
- Never commit generated graphics, text, maps, audio, or other copyrighted
  game content.
- Do not paste extracted game content into tests or documentation.
- Synthetic fixtures must be original and deliberately unlike real game data.
- New ROM profiles must be keyed by an exact cryptographic hash.
- Code adapted from another project must have compatible licensing and clear
  provenance.

## Engineering rules

- Runtime systems must not read ROM addresses directly.
- Game and map behavior must be implemented as native Lua, not by executing or
  translating ROM event bytecode.
- All time access must eventually go through the injectable clock service.
- Battle and world calculations should use explicit integer operations.
- Version differences belong in profiles, data, or named rules—not scattered
  string comparisons.
- A new script command or map-specific behavior requires tests and a source
  citation to the relevant reference-disassembly behavior.
- Generated cache schemas and native save schemas must be versioned.

Run `scripts/test.ps1` or `scripts/test.sh` before submitting a change.
