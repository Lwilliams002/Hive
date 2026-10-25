# Hive

Hive is an iOS tower-defense roguelite. A honeycomb hive sits at the centre of the screen and fires stingers at the nearest enemy automatically; waves of wasps, hornets and a boss bear close in from every side. Collected nectar levels you up and offers a choice of three upgrade cards. The boss bear does not die on contact: it parks at the edge of the hive and hits it every second, so it must be killed to clear the level. Lose all hive HP and the run ends (retry from the end overlay). The pause button at the top right (and backgrounding the app) pauses play behind a RESUME overlay. Pure game logic lives in the Swift package `HiveCore`; the SpriteKit app is under `Hive/`.

## Commands

Run the logic tests:

```
cd HiveCore && swift test
```

Build the app for the simulator (the first `xcodegen generate`/build resolves GoogleMobileAds and GoogleUserMessagingPlatform and needs network access):

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

## Mobs

| Type | HP | Speed | Contact dmg | Radius | Nectar | Boss | Armor | Escorts |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| wasp | 20 | 90 | 10 | 10 | 1 | no | 0 | - |
| hornet | 60 | 55 | 20 | 14 | 3 | no | 0 | - |
| beetle | 90 | 40 | 25 | 13 | 4 | no | 5 | - |
| bear | 450 | 28 | 40 | 30 | 15 | yes | 0 | - |
| hornetQueen | 700 | 32 | 35 | 26 | 20 | yes | 0 | 2 hornets every 6 s, first at 3 s |
| swarmMother | 380 | 45 | 25 | 22 | 18 | yes | 0 | 4 wasps every 4 s, first at 2 s |

Armor is a flat per-hit reduction (minimum 1 damage). Escorts spawn at the parent's position offset by `radius + 8` toward the hive, count as normal mobs, stop when the parent dies, and do not spawn during a card pick. Level JSON mob types: `wasp`, `hornet`, `beetle`, `bear`, `hornetQueen`, `swarmMother`; waves may also carry `hpScale`.

## Cards

A card is offered only once `unlockLevel <= highestClearedLevel` (story level L offers cards unlocked through L - 1; level 1 uses the original six). Draw weights: common 70, rare 25, epic `min(25, 5 + 3 * nectar level)`. Starting cards never include heal-only or epic cards.

| Card | Rarity | Effect | Unlock |
| --- | --- | --- | --- |
| Rapid Stingers | common | +25% fire rate | 0 |
| Venom | common | +30% damage | 0 |
| Propolis Armor | common | +30 max HP, heal 30 | 0 |
| Royal Jelly | common | heal 50% of max HP | 0 |
| Twin Stinger | rare | +1 projectile | 0 |
| Piercing Stinger | rare | pierce +1 mob | 0 |
| Honey Field | rare | mobs within 160 of the hive move 35% slower | 0 |
| Guard Bees | rare | +2 bees orbit the hive, 6 damage on touch | 0 |
| Pollen Cloud | rare | hits spread 40% damage to mobs within 45 | 0 |
| Queen's Wrath | epic | +60% damage | 5 |
| Thick Wax | epic | hive takes 30% less contact damage | 7 |
| Swarm Call | epic | +2 projectiles | 10 |
| Royal Guard | epic | +3 bees, bee damage doubled | 15 |

## Permanent tier gating

| Tiers | Require `highestClearedLevel` |
| --- | --- |
| 1-5 | always |
| 6-8 | 8 |
| 9-10 | 16 |

A locked next tier shows a disabled `LVL n` button and `Unlocks after level n` on the row; `GameState.purchase` refuses it.

## Endless

Unlocked when `highestClearedLevel >= 10`. It never clears; a run ends on game over or quit and records its best wave. Wave n (n >= 1):

| Group | Count | Interval |
| --- | --- | --- |
| wasps | 8 + 2n | max(0.25, 0.8 - 0.015n) s |
| hornets (n >= 2) | n / 2 | 2.0 s |
| beetles (n >= 4) | n / 3 | 2.5 s |
| boss (every 5th wave) | 1, cycling bear, hornetQueen, swarmMother | - |

`hpScale = 1 + 0.06n`, 2.0 s between waves. Coins: sum over k = 1...n of (12 + 6k), times the coin multiplier.

## Level generator

Levels 2-30 are generated; level 1 is hand-kept (`testLevelOneUnchanged` hashes it). Edit the per-level `difficulty` (and name/boss) in `Tools/level-table.json`, then from the repo root:

```
swift Tools/genlevels.swift
```

The formulas are in the header of `Tools/genlevels.swift`. Re-run the probes after changing the table.

## Probes

`LevelCurveProbeTests` plays each probed level headlessly (greedy policy, seeds 1...20, 1/30 s ticks, 420 s cap) with the card pool the app offers at that level, at the expected tier count `T = min(50, Int((L - 1) * 1.2))` and at a "behind" loadout (`T - max(4, min(6, T / 4))`).

```
cd HiveCore && swift test                                      # default levels 2,3,4,5,7,10,13,16,20,25,30
HIVE_FULL_PROBE=1 swift test --filter LevelCurveProbeTests     # every level 2...30
HIVE_PROBE_LEVELS=4,9 swift test --filter LevelCurveProbeTests # chosen levels
swift test --skip LevelCurveProbeTests                         # everything else, fast
```

| Bound | Default |
| --- | --- |
| cleared at expected T | >= 10/20 |
| L2-3 at expected | <= 18/20 |
| L >= 4 behind | <= 7/20 |
| L >= 4 at expected | <= 19/20 |
| L >= 4 behind average end wave | >= 2.0 (never overridden) |

Overrides (`LevelCurveOverrides`; levels sitting on a difficulty cliff):

| Level | At expected max | Behind max |
| --- | --- | --- |
| 4 | 19 | 9 |
| 11 | 20 | 7 |
| 13 | 20 | 7 |
| 14 | 20 | 7 |
| 16 | 19 | 8 |
| 19 | 20 | 8 |
| 23 | 19 | 8 |

## Flow

- Home: coin balance, the hive drawn at its current visual tier, and PLAY / LEVELS / UPGRADES (ENDLESS is locked until level 10). PLAY starts the current level (the first not yet cleared, or the last available level once all are cleared).
- LEVELS: 30 rows, tagged CLEARED, CURRENT or LOCKED, clipped under the title. Opens scrolled to the CURRENT row; tap a CLEARED or CURRENT row to play it; the list scrolls by dragging.
- UPGRADES: spend coins on the five permanent tracks with a live hive preview.
- Results (after a run): CONTINUE (only after a clear, and only if the next level exists), RETRY, HOME. Coins are awarded when the run ends.

## Ads

Google AdMob, four placements, no banner anywhere. Every rule that can be stated without the SDK lives in `HiveCore` (`AdRules`, `GameState`, `World`); the app's `AdProviding` (`AdMobProvider` on Google Mobile Ads v12 + UMP v3, `NoAdsProvider` otherwise) is owned by `AppFlow`, and scenes only ask it whether an ad is ready. A control whose ad is not loaded is hidden, never shown broken.

| Placement | Type | Trigger | Rule |
| --- | --- | --- | --- |
| Revive | rewarded | hive HP hits zero while the ad system is up and a rewarded ad is loaded | Once per run. THE HIVE IS FALLING offers REVIVE (watch, then the hive is rebuilt at 50% HP, bosses wait at least 1.5 s, non-boss mobs within 150 pt are pushed back out) or GIVE UP. With no ad loaded the run simply ends. A second fall ends the run at once; a revived clear counts. |
| Double coins | rewarded | results card after a story clear or any endless end (never a story loss) with coins earned and a rewarded ad loaded | Pays the card's `+N coins` a second time, once per run (`bonusAwardedRunIDs`); the button then reads DOUBLED. A cancelled ad brings the button back only while another ad is ready. |
| Premium card | rewarded | a card pick, on about 1 in 3 picks | A fourth row, WATCH TO TAKE, with a card still locked at this level (story level L: `unlockLevel > L - 1`, so level 1 offers the four epics; endless: locked above `highestClearedLevel`; none from 15, so the row never appears). Taking it replaces the regular pick, for this run only. Rolled on its own RNG stream, so the three regular cards are unchanged; the row is omitted when no rewarded ad is loaded, and a cancelled ad leaves the same four rows with the fourth dimmed. |
| Interstitial | interstitial | CONTINUE, RETRY or HOME on the results card | Shown between the card and the next screen when `AdRules` permits; never over the card, never during play, never from the pause menu's RETRY / HOME (those quit a run rather than end it). |

Frequency (`AdRules` in `HiveCore/Sources/HiveCore/Progression/AdRules.swift`, unit-tested on Linux): an interstitial needs `levelsEnded > 3` (the first three run ends of a fresh install are ad-free), at least 3 run ends since the last interstitial, and no rewarded ad within the last 90 s (a clock set backwards counts as still inside the cooldown). `levelsEnded` counts every recorded run end: story clear, story loss, endless end and a run quit from the pause menu. The slot is consumed when the show is requested, so a failed present means fewer ads, never more.

Consent runs once, after the first story run ends (any outcome), over that run's results card, never on launch: UMP consent form (when required), then the App Tracking Transparency prompt (when not yet answered), then `MobileAds.shared.start`, then preload. No ad loads before it. The app is tagged not child-directed and not under the age of consent, max ad content rating T. `consentPrompted` in the save remembers that the flow ran; later launches start the SDK directly (UMP re-prompts on its own when it must).

IDs: DEBUG builds always use Google's test IDs (App ID `ca-app-pub-3940256099942544~1458002511` in `Info.plist`, rewarded `ca-app-pub-3940256099942544/1712485313`, interstitial `ca-app-pub-3940256099942544/4411468910`). Release builds read `Hive/Resources/AdConfig.plist` (gitignored; keys `RewardedAdUnitID` and `InterstitialAdUnitID`) and fall back to the test IDs when the file or a key is missing; real IDs are milestone 5.

DEBUG hooks (environment variables; with `xcrun simctl launch` they take the `SIMCTL_CHILD_` prefix, e.g. `SIMCTL_CHILD_HIVE_FAKE_ADS=grant xcrun simctl launch booted com.lwilliams.hive`):

| Variable | Effect |
| --- | --- |
| `HIVE_FAKE_ADS=grant` or `cancel` | No SDK: the fake provider starts at the consent trigger like the real one, every placement then reads as ready, and a fake ad lasts 0.5 s and grants the reward (`grant`) or not (`cancel`). |
| `HIVE_UMP_DEBUG_EEA=1` | Forces the EEA consent form on the simulator (AdMob build). |
| `HIVE_START_HP=<hp>` | The run starts at that HP (clamped to max); `0` downs the hive on the first frame, which is the revive-and-clear check. |

Save fields added for ads (all optional on decode; the save `version` stays 1): `levelsEnded`, `lastInterstitialAtLevelsEnded`, `lastRewardedAdAt` (unix seconds, or null), `consentPrompted`, `bonusAwardedRunIDs`.

## Save file

Progress (coins, upgrade tiers, highest cleared level) is stored as `save.json` in the app's Application Support directory under `Hive/` (`Library/Application Support/Hive/save.json` in the app container). It is written after every purchase and every counted run, and after every ad reward, interstitial and the consent prompt. If the file cannot be decoded (or is from a newer version), it is moved aside to a backup next to it and the game starts from a fresh save.

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
