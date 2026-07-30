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
8. Route, Cherrygrove, and Violet event behavior. **Complete.**
9. Pack, party, and Pokédex UI. **Complete.**
10. Pokémon Center, mart, and PC systems. **Complete.**
11. Save/load and RTC persistence. **Complete.**
12. Music, SFX, and cries. **Complete.**
13. Falkner Gym and badge progression. **Complete.**
14. Automated introduction-to-first-badge acceptance route. **Complete.**
15. Decoded Crystal font and exact gender screen. **Complete.**
16. Faithful clock, professor, naming, and shrink presentation.
17. Explicit verified object/background-event bindings.
18. Complete live-slice ROM dialogue with no semantic fallback.
19. Compact ROM audio-program extraction.
20. Native channel synthesis and exact audio routing.
21. Visible clean-save fidelity acceptance.

Each checkpoint is one local commit. The original functional route exposed
presentation placeholders during hands-on testing, so M5 is reopened. It is
complete only when the route is faithful through visible application states
and passes both its ROM-gated functional and live-fidelity acceptance drivers.

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

## Route and city behavior

M5-008 expands the source-controlled catalog to 20 definitions, including 19
map scripts. Route 29–32/36, Cherrygrove, Violet, Mr. Pokémon's house, the
academy, route gates, and relevant houses now expose native callbacks, scenes,
coordinate gates, object interactions, signs, fruit, and one-time items. Every
game-specific module cites the exact pinned `pokecrystal` source labels used to
study its behavior.

The visible story path now covers Cherrygrove's guide and Map Card, Mr.
Pokémon's Mystery Egg handoff, Oak's Pokédex handoff, the returning rival
battle, Route 30/31 interactions, Violet's city behavior, and Route 32's
pre-badge guard. The same persistent `GameSession` retains those gates.

The player-ROM text catalog grows from 55 to 96 records for the key guide,
Mr. Pokémon, rival, route, and Violet dialogue. Other newly wired interactions
continue to use explicit semantic fallbacks until their ROM labels are added;
the final M5 acceptance checkpoint must remove those fallbacks from the
required introduction-to-badge route.

## Field menu presentation

M5-009 adds a transparent `FieldMenuState` opened with Start while the world is
idle. Its presentation controller reads the current `GameSession`, so Pack
quantities, party HP/levels/held items, and Pokédex discoveries remain current
after scripts and battles without copying state into the UI.

Party species and the 251-entry Pokédex resolve their names and base stats from
normalized data decoded from the player's verified ROM. Unseen Pokédex entries
remain hidden, and the Pokédex cannot be selected before Oak's feature flag is
granted. Pack item labels remain semantic runtime labels at this checkpoint;
ROM-owned item naming, consuming items, buying/selling, healing, and storage
belong to M5-010.

## Facilities

M5-010 recognizes the nurse and clerk objects decoded from the Cherrygrove and
Violet Center/Mart maps and opens native visible facility states. Centers
restore calculated maximum HP for the full persistent party and provide
access to PC deposit/withdrawal. The PC refuses to deposit the final usable
party member and its detached contents are included in session snapshots.

Marts provide source-defined early-game catalogs, buy/sell prices, quantity
changes, and money updates. The underlying facility service also provides
Potion use with calculated HP limits. Item IDs and labels remain semantic at
this checkpoint; a complete ROM-derived item record catalog is campaign work
beyond this first-badge slice.

## Native saves and RTC

M5-011 wraps the detached `GameSession` snapshot in a versioned, checksummed
native-save envelope bound to the exact ROM profile. Saving stages a new file,
rotates the previous primary to a backup, and promotes only the complete staged
file. Loading falls back to the backup when the primary is corrupt.

Start-menu Save writes through LÖVE's application save directory, and launch
restores the profile-matching save before showing the introduction. Player map,
position, and facing resume in the decoded world. RTC reconciliation advances
the in-game hour, minute, and weekday by host elapsed seconds; a backward host
clock is reported and contributes zero elapsed time.

## Slice audio

M5-012 connects the existing semantic audio commands to a runtime dispatcher
and LÖVE audio sink. Introduction, overworld map groups, battles, field/facility
menus, and ROM-derived battle species now schedule music, SFX, and cries with
correct state transitions; resuming the world restores its map music.

The M5-012 sink generates small placeholder square-wave cues from semantic IDs.
This keeps event timing testable headlessly, but it is not cartridge audio.
M5-019 and M5-020 must replace it with compact channel programs decoded from
the verified player ROM and native synthesis of Crystal's music, SFX, and cry
parameters.

## Falkner Gym

M5-013 adds the 20th map definition and full Violet Gym interaction coverage:
both sight trainers, Falkner, guide, and statues. Falkner's two-member party is
decoded from the player's ROM as an explicit leader reference and dispatched
through the existing native smart-AI battle bridge.

Victory persists the story completion and Zephyr Badge flags, marks both Gym
trainers complete as in the reference behavior, plays the badge cue, grants
TM31, and changes repeat dialogue. A loss grants nothing. Route 32's existing
badge guard now observes this same persistent flag and stops returning the
player to Violet.

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

## Acceptance result

M5-014 supplies a canonical player-ROM-gated route driver over the real
introduction and map-script services. It completes Elm's request and starter,
Mr. Pokémon and Oak, the Cherrygrove rival, Falkner, Zephyr Badge, TM31, and a
native save/reload. It also verifies the continuous ten-map route catalog and
constructs Falkner's native ROM-backed battle session.

The driver records every dialogue request it encounters and fails immediately
if the exact entry is absent from the player-ROM catalog. Adding twelve Violet
Gym records, the gender prompt, clock dialogue, and supported-map interaction
records bring that catalog to 217
and close all 37
distinct route dialogue
requests exercised by the acceptance path. Source control retains only stable
IDs and pinned symbol offsets.
