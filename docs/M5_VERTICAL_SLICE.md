# M5 Violet City vertical slice

M5 turns the verified engine slices into the first continuously playable
Crystal route: introduction, New Bark, Cherrygrove, early routes, Violet City,
Falkner's Gym, and the first badge.

## Checkpoint order

1. Persistent game-session and vertical-slice contract.
2. ROM-owned dialogue catalog.
3. Visible battle scene and command menus.
4. World/script-to-battle bridge.
5. World extraction through Violet City.
6. Time-based wild encounters.
7. Trainer sight and trainer battles.
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
M5-002 will decode exact dialogue from the verified player ROM into the
private runtime/cache model. Semantic labels remain the fallback when a text
record is unavailable; original dialogue is never added to source control.

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
