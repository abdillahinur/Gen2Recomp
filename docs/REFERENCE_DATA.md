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
by the M1 extraction slice resolve to the same physical offsets in v1.0 and
v1.1, but each ROM revision still owns a distinct generated manifest, profile,
hash, header version, and private-cache directory.

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
