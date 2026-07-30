# Reference-data generation

The runtime importer uses a compact set of audited ROM addresses. Those
addresses are generated from RGBDS symbol output produced by an exact,
developer-pinned `pret/pokecrystal` revision.

Pinned inputs are recorded in
[`references/pokecrystal.lock.json`](../references/pokecrystal.lock.json):

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
```

Generation fails if the input hash differs, a required label is absent, a
label is duplicated, or an address does not fit its Game Boy ROM window.
Output contains only label, bank, address, physical offset, and reference
provenance.

The initial symbol set bounds Crystal's main 1bpp font, two 2bpp supplemental
font sets, species records, names, and the first tileset slice. The importer
normalizes graphics into palette-index arrays. Its English character map is
native source-controlled metadata; control bytes remain typed tokens rather
than being mistaken for display glyphs.

Crystal species extraction validates all 251 32-byte records against their
table index and decodes the first 251 fixed-width names. Stats, types, held
items, gender thresholds, hatch cycles, dimensions, growth rates, egg groups,
and the 60 TM/HM/tutor compatibility flags become explicit normalized fields.
