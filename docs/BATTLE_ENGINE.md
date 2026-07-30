# Battle engine

M4 is a presentation-independent Gen 2 battle slice. M5-003 now layers a
visible LÖVE battle scene and command menus over that unchanged native session
API.

## Data boundary

`CrystalBattleData` decodes all 251 species and 251 move records from a
verified player ROM. Repository manifests contain only the bank/address
boundaries and enum interpretations required to normalize those records.
Runtime IDs include the cartridge record number and a readable slug, so names
remain unambiguous without committing extracted content.

Mono-type species are normalized to one type. Move bytes become native type,
power, accuracy, PP, priority, critical-level, effect, and effect-chance
fields. Unsupported effect commands safely use the neutral damage/status-move
path until a named Lua implementation is added.

## Simulation boundary

The battle core owns:

- seeded or injected randomness;
- player and opponent parties, active slots, commands, turns, and events;
- switch-before-move ordering, priority, modified Speed, and random tie breaks;
- Gen 2 integer damage, STAB, type effectiveness, critical hits, accuracy, and
  damage variation;
- major and volatile status foundations plus end-turn residual damage;
- native effect dispatch for baseline damage, status, stat stages, drain,
  recoil, and flinch;
- basic and type-aware trainer AI;
- catching, experience rewards, level-up, stat recalculation, and move
  learning;
- forced replacements and terminal player-win, opponent-win, draw, and caught
  outcomes.

`BattleSession` joins these systems without depending on rendering. The UI
submits the same move, switch, catch, and escape commands and consumes the
emitted semantic events.

## M5 presentation adapter

`BattlePresentation` converts the session state and semantic event stream into
testable view models for:

- opponent/player HP, level, and status HUDs;
- turn messages and terminal outcomes;
- Fight, Pack, Pokémon, and Run;
- move names, types, and current/maximum PP;
- party HP, active slot, switching, and disabled choices;
- catching, wild escape, and rejected trainer escape.

`BattleSceneState` draws those models on the 160×144 native canvas. The current
scene uses source-authored silhouettes rather than bundled Pokémon pictures.

M5-004's `BattleBridge` now pushes this state for hand-written script requests
and returns its acknowledged result to the waiting coroutine. Its request
factory adapts persistent semantic party records into native battle instances,
then commits HP, experience, DVs, moves, PP, and Pokédex state back into the
game session. M5-006 now originates ordinary, time-selected encounters from
eligible world steps through the same bridge.

## M4 acceptance fixtures

Run:

```powershell
./scripts/verify-crystal-battles.ps1 -RomPath "<path-to-ROM>"
```

The verifier identifies the ROM, decodes normalized battle records, audits the
result for retained raw ROM ranges, and executes two deterministic fixtures:

1. a level-five first-rival battle using the correct counter-starter;
2. an ordinary low-level Route 29 wild battle.

Both must reach one terminal player-win event and one experience award within
100 turns. The canonical English Crystal v1.1 profile currently passes.

## Reference and remaining scope

The implementation was checked against `pret/pokecrystal` source revision
`3438c7003a57fa2987fcb223d14b660761b33c64`, especially:

- `data/moves/moves.asm`, `data/moves/names.asm`, and move/type constants;
- `engine/battle/core.asm`, `engine/battle/effect_commands.asm`, and
  `engine/battle/hidden_power.asm`;
- `engine/pokemon/mon_stats.asm`, `engine/pokemon/experience.asm`, and
  `data/growth_rates.asm`;
- `data/types/type_matchups.asm` and
  `data/battle/critical_hit_chances.asm`.

M4/M5-003 are not full battle parity. Struggle/no-PP fallback, the complete
move-effect catalog, held-item activation, weather, multi-battle formats,
Pokémon picture extraction, animations, audio, and differential emulator
coverage remain later work. Each complex cartridge routine should enter the
native engine as a named, directly tested Lua implementation.
