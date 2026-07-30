# M5 Violet City vertical slice

M5 turns the verified engine slices into the first continuously playable
Crystal route: introduction, New Bark, Cherrygrove, early routes, Violet City,
Falkner's Gym, and the first badge.

## Checkpoint order

1. Persistent game-session and vertical-slice contract.
2. ROM-owned dialogue catalog. **Complete.**
3. Visible battle scene and command menus. **Complete.**
4. World/script-to-battle bridge. **Complete.**
5. World extraction through Violet City. **Complete.**
6. Time-based wild encounters. **Complete.**
7. Trainer sight and trainer battles. **Complete.**
8. Route, Cherrygrove, and Violet event behavior.
9. Pack, party, and Pokédex UI.
10. Pokémon Center, mart, and PC systems.
11. Save/load and RTC persistence.
12. Music, SFX, and cries.
13. Falkner Gym and badge progression.
14. Automated introduction-to-first-badge acceptance route.

Each checkpoint is one local commit. M5 is complete only when the final route
is playable through visible application states and passes its ROM-gated
acceptance driver.

## Runtime ownership

`GameSession` is the stable owner for state that survives map and application
state changes:

- exact ROM profile ID and snapshot schema;
- script flags, scenes, and variables;
- party members, inventory quantities, and phone contacts;
- in-game hour, minute, and weekday;
- money and player map position/facing;
- Pokédex seen and caught sets.

Snapshots contain detached data only. They do not retain a ROM reader, LÖVE
objects, coroutines, active presentation requests, or runtime adapters.
Snapshot restore rejects schema and ROM-profile mismatches.

M5-001 defines this in-memory contract. Atomic save files, backup/recovery,
host-time reconciliation, and migration handling belong to M5-011.

## Content boundary

The repository continues to store behavior and extraction metadata only.
M5-002 decodes 55 introduction, New Bark, and Elm's Lab dialogue records from
the verified player ROM into normalized runtime tokens. The visible controller
paginates those records into the two-line viewport and resolves player/species
substitutions. Semantic labels remain the fallback when a text record is
unavailable; original dialogue is never added to source control.

The committed manifest contains stable semantic IDs, audited RGBDS symbol
names, and substitution metadata—not dialogue bytes or strings. Both Crystal
US v1.0 and v1.1 use independently generated pinned symbol offsets.

## Battle presentation boundary

M5-003 adds a native `BattleSceneState` and presentation controller over the
M4 `BattleSession`. It exposes HP/status HUDs, event messages, Fight, Pack,
Pokémon, Run, move/PP details, party switching, catching, escaping, failed
trainer escape, and acknowledged terminal outcomes. The standalone ROM-backed
battle preview uses normalized species and move names from the supplied ROM.

Species are represented by native silhouettes until battle-picture extraction
is added, while all battle state and menu behavior already use the real native
simulation.

## Battle dispatch and persistence

M5-004 connects `MapPresentationRuntime` battle waits to a stack-based
`BattleBridge`. A native request factory converts the persistent semantic party
into ROM-backed Pokémon instances, creates wild or trainer sessions, pushes
the visible scene, and returns a structured outcome to the suspended Lua
coroutine after the scene is acknowledged and popped.

Battle completion writes level, HP, experience, DVs, moves, and PP back to the
profile-bound `GameSession`; encountered/caught species update its Pokédex
sets. Those enriched party fields round-trip through the existing detached
snapshot contract. Route encounters themselves begin in M5-006.

## First-badge world corridor

M5-005 expands the player-ROM-backed catalog to 29 maps and 41 headers across
the New Bark, Cherrygrove, and Violet groups. The continuous connection chain
now covers New Bark, Route 29, Cherrygrove, Routes 30 and 31, and Violet City.
Relevant marts, Pokémon Centers, houses, gates, Elm's Lab, and Violet Gym are
also extracted with ten normalized tilesets and the referenced ordinary
overworld sprites.

Crystal's Pokémon, day-care, and variable sprite IDs are preserved as semantic
object metadata and are not mistaken for entries in the ordinary sprite
graphics table. The M5-008 event layer will resolve those script-selected
appearances. Sprout Tower is the one explicit external Violet City warp
boundary; it is not required by the first-badge route currently defined for
M5.

## Time-based wild encounters

M5-006 decodes Crystal's Johto grass and water encounter records from the
verified player ROM, retaining only the eight records referenced by the
first-badge world corridor. Morning, day, and night grass slots use the native
30/30/20/10/5/4/1 weighting; water uses 60/30/10 and Crystal's level variation
thresholds.

`EncounterController` observes completed world steps after higher-priority map
scripts, enforces Crystal's five-step map-entry cooldown, checks the destination
collision, selects the session clock period, and sends a normalized wild
request through the M5-004 battle bridge. Battles cannot start without a usable
party, and completing one restores the cooldown.

## Trainer sight and battles

M5-007 decodes only trainer parties referenced by the selected world maps from
Crystal's `TrainerGroups` table. Trainer names, party types, species, levels,
held-item IDs, and explicit moves remain player-ROM-owned normalized runtime
data; no trainer names or party records are committed as content.

Trainer objects retain their static facing, sight range, class/party reference,
and defeat flag. After a completed player step, `TrainerController` checks an
unobstructed row or column in the trainer's facing direction, displays a native
shock emote, walks the trainer to the adjacent cell, faces the player, and
dispatches a trainer request through the M5-004 battle bridge. A victory stores
the trainer's stable defeat flag in the profile-bound game session, preventing
repeat challenges.

The current battle factory uses explicit ROM move lists when a trainer-party
record supplies them. Ordinary trainer records without explicit moves continue
to use the M4 baseline default move until learnset decoding is added.

## Exit gate

A clean Crystal v1.1 session must visibly complete:

```text
introduction → starter → Route 29 → Cherrygrove → Route 30/31
→ Violet City systems → Falkner battle → Zephyr Badge
```

The route must preserve progress across a real save/load cycle, select
encounters from the injected clock period, resolve required trainer and wild
battles through the native engine, and contain no bundled or retained ROM
content.
