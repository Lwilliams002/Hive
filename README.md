# Hive

Hive is an iOS tower-defense roguelite. A honeycomb hive sits at the centre of the screen and fires stingers at the nearest enemy automatically; waves of wasps, hornets and a boss bear close in from every side. Collected nectar levels you up and offers a choice of three upgrade cards. Lose all hive HP and the run ends (retry from the end overlay). Pure game logic lives in the Swift package `HiveCore`; the SpriteKit app is under `Hive/`.

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

`HiveCore/Tests/HiveCoreTests/BalanceProbeTests.swift` runs level 1 headlessly (seeds 1...20, always pick the first card) and prints a `BalanceProbe:` summary; re-run it after tuning numbers.

## Docs

- Design spec: `docs/superpowers/specs/2026-10-22-hive-defense-design.md`
- Milestone 1 plan: `docs/superpowers/plans/2026-10-22-m1-playable-core.md`
