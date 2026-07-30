# Content and provenance policy

## Repository contents

This repository may contain:

- original native engine code;
- hand-written Lua implementations of engine and map behavior;
- metadata describing how to locate or interpret structures in a verified ROM;
- cryptographic hashes of supported ROM releases;
- original synthetic test fixtures;
- developer tools that consume a separately obtained reference disassembly;
- documentation and behavioral notes written in our own words.

It must not contain:

- ROM images or patches containing copyrighted ROM data;
- cartridge save files;
- extracted maps, text, graphics, music, sound effects, or cries;
- private generated caches;
- screenshots or recordings derived from a ROM unless a future project policy
  explicitly permits a narrow documentation use;
- copied source whose license is unknown or incompatible.

## Runtime import

The planned importer will:

1. Hash and identify a player-selected ROM.
2. Refuse unknown or modified ROMs by default.
3. Decode content into a versioned private cache.
4. Validate the completed cache.
5. Avoid storing the original ROM or unnecessary raw ROM ranges.
6. Release the ROM from memory after import.

Cache writes must be transactional so that cancellation or failure cannot
replace a valid cache with a partial one.

The importer may decode static content such as tables, text, layouts, object
metadata, graphics, palettes, and compact audio programs. It must not turn the
original event bytecode or assembly into the runtime implementation. Map
events, battles, menus, and other behavior are rewritten as native Lua.

## Reference projects

The pret `pokecrystal` and `pokegold` disassemblies are technical references
and developer-time inputs. They are not runtime dependencies and will not be
downloaded by the packaged game.

Any reusable code adapted from Gen1Recomp must retain its required license and
provenance. Game-specific data or extracted content from that project must not
be copied.

## Automated safeguards

Current safeguards include:

- broad ignore rules for ROM, save, cache, and RGBDS output formats;
- a repository content scanner used by tests and CI;
- CI checks for forbidden extensions and suspicious large binary files;
- cache-retention tests that search for large unprocessed ROM regions;
- review requirements for changes to ROM profiles and extraction metadata;
- validated stable IDs, coverage declarations, and exact pinned provenance for
  every game-specific Lua behavior definition.
