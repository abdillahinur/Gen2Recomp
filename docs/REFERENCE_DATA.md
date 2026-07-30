# Reference-data generation

The runtime importer uses a compact set of audited ROM addresses. Those
addresses are generated from RGBDS symbol output produced by an exact,
developer-pinned `pret/pokecrystal` revision.

Pinned inputs are recorded separately for
[Crystal v1.0](../references/pokecrystal.lock.json) and
[Crystal v1.1](../references/pokecrystal11.lock.json):

- source revision;
- generated-symbol branch revision;
- required RGBDS version;
- SHA-256 of the complete `.sym` input;
- target ROM profile.

The full `.sym` file is a developer-time input and is not committed or
downloaded by the packaged application. Regenerate the compact manifest with:

```powershell
python tools/generate_symbol_manifest.py `
  --symbols C:\path\to\pokecrystal.sym `
  --allowlist tools/symbols/crystal_us_10_symbols.txt `
  --lock references/pokecrystal.lock.json `
  --output manifests/crystal_us_10_symbols.lua

python tools/generate_symbol_manifest.py `
  --symbols C:\path\to\pokecrystal11.sym `
  --allowlist tools/symbols/crystal_us_11_symbols.txt `
  --lock references/pokecrystal11.lock.json `
  --output manifests/crystal_us_11_symbols.lua
```

Generation fails if the input hash differs, a required label is absent, a
label is duplicated, or an address does not fit its Game Boy ROM window.
Output contains only label, bank, address, physical offset, and reference
provenance.

The two full symbol files have different SHA-256 fingerprints. All labels used
by the M1 and M2 extraction slices resolve to the same physical offsets in v1.0
and v1.1, but each ROM revision still owns a distinct generated manifest,
profile, hash, header version, and private-cache directory.

The initial symbol set bounds Crystal's main 1bpp font, two 2bpp supplemental
font sets, species records, names, and the first tileset slice. The importer
normalizes graphics into palette-index arrays. Its English character map is
native source-controlled metadata; control bytes remain typed tokens rather
than being mistaken for display glyphs.

Crystal species extraction validates all 251 32-byte records against their
table index and decodes the first 251 fixed-width names. Stats, types, held
items, gender thresholds, hatch cycles, dimensions, growth rates, egg groups,
and the 60 TM/HM/tutor compatibility flags become explicit normalized fields.

The first tileset slice implements Crystal's bounded LZ format and extracts the
Johto set as 192 normalized 2bpp tiles, 128 4x4 metatiles, 128 2x2 collision
records, and 224 tile palette/VRAM slots. The slot model preserves Crystal's
96-bank-0, 32-reserved, 96-bank-1 layout. Its base colors are decoded from
15-bit Game Boy values into named time-of-day palettes with both 5-bit and
8-bit RGB channels.

M2 adds the compact addresses needed for Crystal's map-group pointer table,
the New Bark group attributes and selected map block/event records, collision
permissions, map-group roofs, roof palettes and tiles, object palettes, and
overworld sprite table. The shared world manifest selects eight maps and four
tilesets needed by the New Bark slice while retaining all thirteen normalized
headers in map group 24.

The importer decodes static map structure only: dimensions, blocks,
connections, warps, coordinate/BG event locations, object metadata, graphics,
and palettes. Original script pointers are deliberately omitted from the
normalized cache. Event behavior will be hand-written in source-controlled Lua
during M3 rather than executing or translating ROM bytecode.

M4 adds a compact, shared Crystal battle manifest for the `Moves` and
`MoveNames` boundaries from the same pinned reference revision. The runtime
adapter combines those 251 records with the existing 251 normalized species
records. It maps numeric type and effect enums to stable native IDs, removes
duplicate mono-type entries, and creates unique semantic IDs containing the
cartridge record number. Move and species names, stats, power, accuracy, PP,
catch rates, and experience values are decoded only from the player-supplied
ROM; they are not committed to the repository.

M5-002 expands both version-specific symbol allowlists with 55 direct text
labels used by the introduction, New Bark, and Elm's Lab. A shared semantic
manifest maps native dialogue IDs to those labels and declares the one runtime
string-buffer substitution required by the slice. The runtime decoder
normalizes glyphs, line/paragraph controls, terminals, and substitutions;
neither the generated symbol manifests nor the semantic manifest contains the
dialogue itself.

M5-006 adds `JohtoGrassWildMons` and `JohtoWaterWildMons` from both exact
version-specific symbol inputs. The importer validates every terminated source
record, then retains normalized rates, species numbers, levels, and weights
only for maps selected by the world manifest. Encounter records remain private
player-ROM-derived cache data.

M5-007 adds `TrainerGroups` from the same two exact symbol inputs. Static
trainer event descriptors contribute class, party, sight, facing, and defeat
flag metadata; script and text pointers are not retained. The trainer-party
decoder follows the referenced class group, validates all four Crystal party
record layouts, and normalizes only parties used by selected maps. Names,
species, levels, held items, and explicit moves are decoded at runtime from the
player's ROM.

M5-008 adds 41 direct dialogue labels for the Cherrygrove guide, Mr. Pokémon
and Oak meeting, first rival gate, Routes 30/31, and Violet City. That expanded
the runtime catalog to 96 records; M5-014 adds twelve Violet Gym records for a
total of 108. M5-015 adds the ROM-owned gender question for a current total of
119. The semantic manifest still contains only IDs, symbol names, and
substitution metadata.
