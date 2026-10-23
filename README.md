# Hive

Hive is an iOS tower-defense roguelite. A honeycomb hive sits at the centre of the screen and fires stingers at the nearest enemy automatically; waves of wasps, hornets and a boss bear close in from every side. Collected nectar levels you up and offers a choice of three upgrade cards. The boss bear does not die on contact: it parks at the edge of the hive and hits it every second, so it must be killed to clear the level. Lose all hive HP and the run ends (retry from the end overlay). The pause button at the top right (and backgrounding the app) pauses play behind a RESUME overlay. Pure game logic lives in the Swift package `HiveCore`; the SpriteKit app is under `Hive/`.

## Commands

Run the logic tests:

```
cd HiveCore && swift test
```

Build the app for the simulator:

```
xcodegen generate && xcodebuild -project Hive.xcodeproj -scheme Hive -destination 'platform=iOS Simulator,id=2B4C8064-73B0-48D3-8246-1CA9711ED4D3' -derivedDataPath build build 2>&1 | tail -5
```

Launch: boot that simulator (or substitute your own device id), then
`xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Hive.app && xcrun simctl launch booted $(defaults read $PWD/build/Build/Products/Debug-iphonesimulator/Hive.app/Info CFBundleIdentifier)`.

## Levels

Levels are JSON in `Hive/Resources/Levels/` (`level_001.json`). The app crashes at launch with `Failed to load level_001.json` if the file is missing or invalid.

- `id`, `name`: level number and title.
- `waves`: ordered list; each wave has
  - `delay`: seconds to wait after the previous wave is cleared before this one starts,
  - `isBoss` (optional, default false): marks a boss wave,
  - `spawns`: list of `{ "type": "wasp" | "hornet" | "bear", "count": n, "interval": seconds between spawns }`.

`HiveCore/Tests/HiveCoreTests/BalanceProbeTests.swift` runs level 1 (the on-ramp) headlessly over seeds 1...20 and prints a summary per probe. Re-run it after tuning numbers or upgrade constants.

- `BalanceProbe:` first-card policy (always take the first card offered), base stats: must clear 4-12 of 20 and reach the boss at least once.
- `BalanceProbe(greedy):` greedy policy (prefer damage cards, heal below 40% HP), base stats: must clear 10-18 of 20 and reach the boss in at least 10 of 20.
- `BalanceProbe(midgame):` greedy policy with Comb, Stinger, Swarm and Queen at tier 3 (stats and starting cards from `PermanentUpgrades`): must clear at least 17 of 20, so permanent progress makes level 1 close to a sure thing.

## Flow

- Home: coin balance, the hive drawn at its current visual tier, and PLAY / LEVELS / UPGRADES (ENDLESS is locked until level 10). PLAY starts the current level (the first not yet cleared, or the last available level once all are cleared).
- LEVELS: one row per level, tagged CLEARED, CURRENT or LOCKED. Tap a CLEARED or CURRENT row to play it; the list scrolls by dragging.
- UPGRADES: spend coins on the five permanent tracks with a live hive preview.
- Results (after a run): CONTINUE (only after a clear, and only if the next level exists), RETRY, HOME. Coins are awarded when the run ends.

## Save file

Progress (coins, upgrade tiers, highest cleared level) is stored as `save.json` in the app's Application Support directory under `Hive/` (`Library/Application Support/Hive/save.json` in the app container). It is written after every purchase and every counted run. If the file cannot be decoded (or is from a newer version), it is moved aside to a backup next to it and the game starts from a fresh save.

## Permanent upgrades

Each track has tiers 1-10. Cost of tier t is `20 + 30 * t^2` coins.

| Track | Effect at tier t |
| --- | --- |
| Comb | max HP = 100 + 15t |
| Stinger | damage = 10 + 1.5t |
| Swarm | fire rate = 2 + 0.15t shots/s; projectiles = 1, +1 at tier 4, +1 at tier 8 |
| Nectar | coin multiplier = 1 + 0.10t |
| Queen | starting upgrade cards = floor(t / 3) |

Tier costs: 1: 50, 2: 140, 3: 290, 4: 500, 5: 770, 6: 1,100, 7: 1,490, 8: 1,940, 9: 2,450, 10: 3,020.

Visual tier of the hive = `1 + (total tiers across all tracks) / 5` (integer division), from 1 up to 11.

## Docs

- Design spec: `docs/superpowers/specs/2026-10-22-hive-defense-design.md`
- Milestone 1 plan: `docs/superpowers/plans/2026-10-22-m1-playable-core.md`
