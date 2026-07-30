# Hand-written map behavior

This directory will contain the source-controlled Lua rewrite of map-specific
Gold, Silver, and Crystal behavior.

The ROM importer may provide static map records, object metadata, text, and
other content. It will not execute or translate the original event bytecode.
Scripts here call native high-level commands implemented by Gen2Recomp.

Planned organization:

```text
data/scripts/
├── common/
├── crystal/
├── gold/
└── silver/
```

Each map script must:

- cite the relevant `pokecrystal` or `pokegold` source file or labels;
- contain no copied dialogue or other extracted game content;
- express scenes, callbacks, interactions, and story behavior in Lua;
- use stable data IDs instead of ROM addresses;
- include focused tests or be covered by an automated gameplay driver.

