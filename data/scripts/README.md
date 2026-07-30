# Hand-written game behavior

This directory contains Gen2Recomp's source-controlled Lua rewrite of
game-specific behavior. Scripts describe intent through native commands. They
do not execute, translate, embed, or dispatch the original event bytecode.

## Organization

```text
data/scripts/
├── common/              original behavior shared by supported games
├── crystal/
│   ├── flows/           introduction, naming, and other cross-map flows
│   └── maps/            map callbacks, scenes, and interactions
├── gold/
└── silver/
```

Every script is a Lua module that returns a data-only definition whose
behavior entries are hand-written Lua functions:

```lua
local Provenance = require("data.scripts.Provenance")

return {
  schema = 1,
  id = "crystal.maps.example",
  game = "crystal",
  kind = "map",
  maps = { "24:4" },
  provenance = {
    Provenance.citation(
      "crystal",
      "maps/Example.asm",
      { "Example_MapScripts", "ExampleNPCScript" },
      "Used to reproduce the callback and NPC interaction sequence."
    ),
  },
  coverage = {
    callbacks = { "crystal.example.callback.initialize" },
    scenes = {},
    coordEvents = {},
    bgEvents = {},
    objects = { "crystal.example.object.npc" },
  },
  behavior = {
    -- Native Lua functions are added here.
  },
}
```

Definitions are validated by `src/script/ScriptDefinition.lua` before they are
registered or executed.

## Stable IDs

- Script and coverage IDs are lowercase dotted names. They describe semantics,
  not source addresses: `crystal.new_bark.object.elm_aide`.
- Maps use normalized `group:map` IDs from the importer: `24:4`.
- Runtime commands use stable content IDs. ROM banks, addresses, pointers,
  opcodes, and script-command numbers are forbidden in behavior modules.
- IDs are persistent save/coverage interfaces. Renaming one later requires an
  explicit migration.

## Provenance

Game-specific behavior requires at least one citation created through
`data.scripts.Provenance`. A citation records:

- the pinned reference repository and exact revision;
- a repository-relative `.asm` path;
- one or more relevant source labels;
- a short note explaining which behavior was studied.

The citation documents behavioral research; it is not permission to copy
implementation code or game content. Reference revisions are pinned centrally
so a script cannot silently cite a moving branch. A future Gold/Silver script
must not be added until `pret/pokegold` has an audited pinned revision.

Source-original `common` modules do not claim game-reference provenance.

## Content boundary

Scripts may contain control flow, semantic IDs, numeric gameplay parameters,
and original implementation comments. They must not contain copied dialogue,
extracted text, maps, graphics, music, sound effects, or other ROM content.
Static content remains player-owned and is decoded from a verified ROM into
the private cache.

Each new behavior must:

1. declare every map it can run on;
2. cite the relevant reference paths and labels;
3. declare callbacks, scenes, coordinate events, BG events, and object
   interactions in its `coverage` table;
4. use the native command API rather than manipulating world/UI internals;
5. include focused tests or an automated flow-driver scenario.
