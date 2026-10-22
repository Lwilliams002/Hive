# Hive — Milestone 2: Progression (coins, home, permanent upgrades, save) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player opens the app to a home screen showing their hive, earns coins by playing levels, spends them on five permanent upgrade tracks that visibly grow the hive and strengthen it in play, picks levels from a list, and finds everything saved when they come back.

**Architecture:** Pure logic stays in `HiveCore`: a `PermanentUpgrades` value (5 tracks × 10 tiers) derives `HiveStats`, a `GameState` holds coins/upgrades/progress and records run results, a `SaveStore` protocol persists it as JSON. The app gains an `AppFlow` coordinator that owns the state and store and presents SpriteKit scenes (`HomeScene`, `UpgradesScene`, `LevelSelectScene`, `GameScene`), and a `HiveRenderer` that builds the hive node tree for a visual tier 1…11. `GameScene` becomes parameterized (level, stats, card pool) instead of loading level 1 itself.

**Tech Stack:** Swift 5 mode on Xcode 26.2, SpriteKit, UIKit with a `UIScene` lifecycle, XcodeGen, XCTest. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-22-hive-defense-design.md` sections 5.4 (permanent progression), 5.5 (hive visuals per tier), 5.6 screens 1–3 and 6 (home, upgrades, level select, level complete), 7 (persistence, architecture), 8 milestone 2. Deferred items from milestone 1 that this plan closes: `docs/superpowers/plans/2026-10-22-m1-deferred-and-rulings.md` lines marked "milestone 2".

## Global Constraints

- iOS 16.0, iPhone only, portrait. Swift language mode 5. `HiveCore` imports Foundation only.
- Visual rules (spec 5.5): background `#0B0A08`; hive amber `#E8A33C` / gold `#F2C14E` / burnt orange `#B8641B`; white accents; thin modern type (`AvenirNext-DemiBold` is the recorded font); minimal chrome; **never childish**. All drawing with `SKShapeNode`/`SKLabelNode`; no image assets.
- Save file: `Application Support/Hive/save.json`, written atomically; a corrupt file is renamed `save.json.corrupt-<timestamp>` and the game starts fresh.
- Five tracks exactly: `comb, stinger, swarm, nectar, queen`; 10 tiers each; tier cost `20 + 30·t²` coins for tier `t` (t = 1…10): 50, 140, 290, 500, 770, 1100, 1490, 1940, 2450, 3020.
- Stat derivation from tiers (additive, on top of `HiveStats.base`): comb `maxHP = 100 + 15·t`; stinger `damage = 10 + 1.5·t`; swarm `fireRate = 2 + 0.15·t` and `projectileCount = 1 + (t ≥ 4 ? 1 : 0) + (t ≥ 8 ? 1 : 0)`; nectar `coinMultiplier = 1 + 0.10·t`; queen `startingCardCount = t / 3` (integer division: 0,0,0,1,1,1,2,2,2,3).
- Coins per run: `perWave = 6 + 2·levelId`; `earned = round((wavesCleared · perWave + (cleared ? 30 + 10·levelId : 0)) · coinMultiplier)`. `wavesCleared` = `totalWaves` when cleared, else `waveNumber − 1`.
- Visual tier `v = 1 + totalTiers / 5` (integer division; totalTiers 0…50 → v 1…11).
- Story progress: `highestClearedLevel` (0 initially); `currentLevel = highestClearedLevel + 1`; a level `id` is playable when `id ≤ currentLevel` and exists in the bundle.
- Existing `HiveCore` tests (39) keep passing unchanged; existing `World.tick` semantics unchanged.
- Build: `cd /Users/lezdev/Desktop/Williams/ad-game && xcodegen generate && xcodebuild -project Hive.xcodeproj -scheme Hive -destination 'platform=iOS Simulator,id=2B4C8064-73B0-48D3-8246-1CA9711ED4D3' -derivedDataPath build build 2>&1 | tail -5`. Commit after every task, `type(scope): summary`, `Co-Authored-By` trailer.

## Review Focus

1. **Relaunch after a purchase**: coins and tiers must survive a kill-and-relaunch; the save must be written at the moment of purchase, not on background. Pinned in Task 2 (`testSaveRoundTrip`) and Task 5 (relaunch check on the simulator).
2. **Corrupt or old-version save file**: the app must start fresh with a backup copy, never crash on launch. Pinned in Task 2 (`testCorruptFileStartsFreshAndKeepsBackup`, `testUnknownVersionStartsFresh`).
3. **Buying with insufficient coins or at max tier**: must be refused with no state change, and the UI must show it as unaffordable. Pinned in Task 1 (`testPurchaseRefusedWhenPoor`, `testPurchaseRefusedAtMaxTier`) and Task 7 (dimmed buttons).
4. **Run ends while the app is backgrounded or the scene is torn down**: coins must be recorded exactly once per run (no double-award on Retry, none lost on Home). Pinned in Task 4 (`AppFlow.runEnded` idempotent per run id, `testRunEndedRecordsOnce`).
5. **Playing a cleared level again**: still pays coins (replays are the grind the spec relies on) but never lowers `highestClearedLevel`. Pinned in Task 2 (`testReplayPaysButDoesNotRegress`).

---

## File Structure

```
HiveCore/Sources/HiveCore/
  Progression/UpgradeTrack.swift        enum + per-track display names/descriptions
  Progression/PermanentUpgrades.swift   tiers, cost, hiveStats(), coinMultiplier, startingCardCount, visualTier
  Progression/RunResult.swift           RunResult + CoinRules.coins(...)
  Progression/GameState.swift           coins, upgrades, highestClearedLevel, purchase, record
  Persistence/SaveStore.swift           protocol + InMemorySaveStore + FileSaveStore
  World/World.swift                     (modify) init gains cardPool + startingCardCount; runID
HiveCore/Tests/HiveCoreTests/
  PermanentUpgradesTests.swift, GameStateTests.swift, SaveStoreTests.swift, WorldStartingCardsTests.swift
  (modify) BalanceProbeTests.swift      + one probe at a mid-game upgrade spread
Hive/
  App/AppDelegate.swift                 (modify) UIScene manifest, no window code
  App/SceneDelegate.swift               window + SKView + AppFlow
  App/AppFlow.swift                     owns GameState/SaveStore/level loader; presents scenes
  App/LevelLoader.swift                 enumerates Levels/level_%03d.json in the bundle
  Rendering/Shapes.swift                hexPath, roundedRect helpers (shared)
  Rendering/Typography.swift            font name + sizes
  Rendering/HiveRenderer.swift          makeHive(visualTier:) -> SKNode (replaces HiveNode)
  Rendering/Button.swift                SKNode button (amber filled / outlined variants), named, enabled flag
  Rendering/EndOverlay.swift            (modify) results: coins, continue/retry/home
  Rendering/HUDNode.swift               (modify) coin counter
  Scenes/HomeScene.swift
  Scenes/UpgradesScene.swift
  Scenes/LevelSelectScene.swift
  Scenes/GameScene.swift                (modify) init(level:stats:cardPool:startingCardCount:flow:), startRun from didMove
  Resources/Info.plist                  (modify) UIApplicationSceneManifest
```

Dependency order: 1 → 2 → 3 (core) → 4 (flow + GameScene) → 5 (renderer) → 6 (home) → 7 (upgrades) → 8 (level select + probe + README).

---

### Task 1: Permanent upgrades (tracks, tiers, costs, stat derivation)

**Files:**
- Create: `HiveCore/Sources/HiveCore/Progression/UpgradeTrack.swift`, `HiveCore/Sources/HiveCore/Progression/PermanentUpgrades.swift`
- Test: `HiveCore/Tests/HiveCoreTests/PermanentUpgradesTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum UpgradeTrack: String, Codable, CaseIterable, Equatable { case comb, stinger, swarm, nectar, queen
      public var displayName: String   // "Comb", "Stinger", "Swarm", "Nectar", "Queen"
      public var summary: String       // "Hive HP", "Damage", "Fire rate & stingers", "Coins per run", "Starting cards"
  }
  public struct PermanentUpgrades: Codable, Equatable {
      public static let maxTier = 10
      public init()                                       // all tiers 0
      public init(tiers: [UpgradeTrack: Int])             // clamps to 0...maxTier
      public func tier(of track: UpgradeTrack) -> Int
      public var totalTiers: Int
      public var visualTier: Int                          // 1 + totalTiers / 5
      public static func cost(forTier t: Int) -> Int      // 20 + 30*t*t, t in 1...10
      public func nextCost(for track: UpgradeTrack) -> Int?   // nil at max
      public mutating func raise(_ track: UpgradeTrack)       // +1, no-op at max
      public func hiveStats() -> HiveStats
      public var coinMultiplier: Double
      public var startingCardCount: Int
      public func effectDescription(for track: UpgradeTrack, atTier t: Int) -> String  // e.g. "HP 145", "Damage 14.5", "Fire rate 2.3/s · 2 stingers", "+30% coins", "1 starting card"
  }
  ```
- Codable form: `{"tiers": {"comb": 0, ...}}` with missing tracks defaulting to 0 (decode via `decodeIfPresent`).

- [ ] **Step 1: Write the failing tests** — `PermanentUpgradesTests`:
  - `testCostsTable`: `cost(forTier:)` for 1…10 equals `[50,140,290,500,770,1100,1490,1940,2450,3020]`.
  - `testStatsAtZeroEqualBase`: `PermanentUpgrades().hiveStats() == HiveStats.base`, `coinMultiplier == 1`, `startingCardCount == 0`, `visualTier == 1`.
  - `testStatsDerivation`: tiers comb 3, stinger 2, swarm 8, nectar 5, queen 7 → `maxHP 145`, `damage 13`, `fireRate 3.2` (±1e-9), `projectileCount 3`, `coinMultiplier 1.5`, `startingCardCount 2`, `totalTiers 25`, `visualTier 6`.
  - `testSwarmProjectileThresholds`: swarm 3 → 1 projectile, 4 → 2, 7 → 2, 8 → 3.
  - `testRaiseClampsAtMax`: raise comb 11 times → tier 10, `nextCost(for: .comb) == nil`.
  - `testCodableRoundTripAndMissingTracks`: encode/decode equals; decoding `{"tiers":{"comb":2}}` gives comb 2 and others 0.
  - `testVisualTierBounds`: all tracks 10 → `visualTier == 11`; all 0 → 1; total 4 → 1; total 5 → 2.
- [ ] **Step 2: Run to verify fail** — `cd HiveCore && swift test --filter PermanentUpgradesTests 2>&1 | grep -E "error:" | head -3`.
- [ ] **Step 3: Implement** both files per the interfaces and Global Constraints formulas. `hiveStats()` starts from `HiveStats.base` and overwrites the four derived fields; `pierce` and `projectileSpeed` stay base.
- [ ] **Step 4: Run to verify pass** — `swift test 2>&1 | tail -2` → `Executed 46 tests, with 0 failures`.
- [ ] **Step 5: Commit** — `feat(core): permanent upgrade tracks, costs, stat derivation`.

---

### Task 2: GameState, run results, coin rules, save store

**Files:**
- Create: `HiveCore/Sources/HiveCore/Progression/RunResult.swift`, `HiveCore/Sources/HiveCore/Progression/GameState.swift`, `HiveCore/Sources/HiveCore/Persistence/SaveStore.swift`
- Test: `HiveCore/Tests/HiveCoreTests/GameStateTests.swift`, `HiveCore/Tests/HiveCoreTests/SaveStoreTests.swift`

**Interfaces:**
- Consumes: `PermanentUpgrades` (Task 1).
- Produces:
  ```swift
  public struct RunResult: Equatable {
      public let runID: UUID; public let levelId: Int; public let cleared: Bool
      public let wavesCleared: Int; public let totalWaves: Int; public let coinsEarned: Int
      public init(runID: UUID, levelId: Int, cleared: Bool, wavesCleared: Int, totalWaves: Int, coinsEarned: Int)
  }
  public enum CoinRules {
      public static func perWave(levelId: Int) -> Int                       // 6 + 2*levelId
      public static func clearBonus(levelId: Int) -> Int                    // 30 + 10*levelId
      public static func coins(levelId: Int, wavesCleared: Int, cleared: Bool, multiplier: Double) -> Int  // rounded
  }
  public struct GameState: Codable, Equatable {
      public static let currentVersion = 1
      public var version: Int; public var coins: Int; public var upgrades: PermanentUpgrades
      public var highestClearedLevel: Int; public var recordedRunIDs: [UUID]   // last 20, for idempotent recording
      public init()                                    // version 1, 0 coins, fresh upgrades, 0 cleared
      public var currentLevel: Int                     // highestClearedLevel + 1
      public func canAfford(_ track: UpgradeTrack) -> Bool
      @discardableResult public mutating func purchase(_ track: UpgradeTrack) -> Bool   // false if poor or maxed; deducts and raises
      @discardableResult public mutating func record(_ result: RunResult) -> Bool       // false if runID already recorded; adds coins, raises highestClearedLevel if cleared && levelId > it
  }
  public enum SaveError: Error { case corrupt(backupPath: String), io(Error) }
  public protocol SaveStore { func load() throws -> GameState?; func save(_ state: GameState) throws }
  public final class InMemorySaveStore: SaveStore { public init(); public var stored: GameState? }
  public final class FileSaveStore: SaveStore {
      public init(directory: URL, fileName: String = "save.json")
      public var fileURL: URL
      // load: nil if no file; if undecodable or version > currentVersion → move to "<fileName>.corrupt-<unix seconds>" and throw .corrupt(backupPath:)
      // save: JSONEncoder (sortedKeys), Data.write(options: .atomic), creating the directory if needed
  }
  ```
- Coins formula check: level 1 cleared, 5 waves, ×1.0 → 5·8 + 40 = **80**; level 1 lost at wave 4 (3 cleared) → **24**; level 3 cleared, 6 waves, ×1.3 → round((6·12 + 60)·1.3) = round(171.6) = **172**.

- [ ] **Step 1: Write the failing tests**
  - `GameStateTests`: `testCoinRulesExamples` (the three numbers above); `testPurchaseDeductsAndRaises` (coins 200, buy comb → coins 150, tier 1; buy comb → 10, tier 2); `testPurchaseRefusedWhenPoor` (coins 49, buy → false, unchanged); `testPurchaseRefusedAtMaxTier` (comb 10, coins 99999 → false, coins unchanged); `testRecordAddsCoinsAndProgress` (fresh, record level 1 cleared 80 coins → coins 80, highestClearedLevel 1, currentLevel 2); `testRecordIsIdempotentPerRunID` (same result twice → second returns false, coins still 80); `testReplayPaysButDoesNotRegress` (highestClearedLevel 3, record level 1 cleared → coins up, still 3; record level 2 lost → coins up, still 3); `testRecordedRunIDsCappedAt20`.
  - `SaveStoreTests` (use a temp directory `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`): `testLoadNilWhenNoFile`; `testSaveRoundTrip` (save a state with coins 123 and comb 2, load → equal); `testSaveIsAtomicAndCreatesDirectory` (directory absent before save, file exists after); `testCorruptFileStartsFreshAndKeepsBackup` (write `{not json` → load throws `.corrupt(backupPath:)`, backup file exists with that content, original gone); `testUnknownVersionStartsFresh` (write a valid JSON with `"version": 99` → throws `.corrupt`); `testInMemoryStore`.
- [ ] **Step 2: Run to verify fail.**
- [ ] **Step 3: Implement** the three files. `record` appends the runID and trims to the last 20.
- [ ] **Step 4: Run to verify pass** — `Executed 60 tests, with 0 failures` (46 + 8 + 6).
- [ ] **Step 5: Commit** — `feat(core): game state, coin rules, run results, JSON save store`.

---

### Task 3: World takes a card pool and starting cards

**Files:**
- Modify: `HiveCore/Sources/HiveCore/World/World.swift`
- Test: `HiveCore/Tests/HiveCoreTests/WorldStartingCardsTests.swift`

**Interfaces:**
- Produces: `public init(level: LevelDefinition, hiveStats: HiveStats = .base, cardPool: [UpgradeCard] = UpgradeCatalog.milestone1, startingCardCount: Int = 0, seed: UInt64)`; `public let runID: UUID` (new, generated in init); `public private(set) var startingCards: [UpgradeCard]`. Starting cards are drawn with `UpgradeCatalog.draw(count:from:rng:)` from `cardPool` at init and applied immediately via `HiveStats.apply(_:to:)`. The pick-time draw in `tick` uses `cardPool` instead of the hard-coded catalog.
- Existing call sites (`World(level:seed:)`, `World(level:hiveStats:seed:)`) keep compiling.

- [ ] **Step 1: Write the failing tests** — `testStartingCardsAppliedAtInit` (pool = `[venom]` only, count 1 → `hive.stats.damage == 13`, `startingCards.count == 1`); `testStartingCardsZeroByDefault`; `testCardPoolUsedForPicks` (pool = `[rapid_stingers, venom, twin_stinger]`, run `tenWasps` level until `.pickingCards(cards)` → every card id is in the pool); `testRunIDUniquePerWorld`; `testStartingCountLargerThanPoolIsClamped` (pool of 2, count 3 → 2 cards).
- [ ] **Step 2: Run to verify fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify pass** — `Executed 65 tests, with 0 failures`.
- [ ] **Step 5: Commit** — `feat(core): world accepts card pool and starting cards; run id`.

---

### Task 4: App flow, UIScene lifecycle, parameterized GameScene, results overlay

**Files:**
- Create: `Hive/App/SceneDelegate.swift`, `Hive/App/AppFlow.swift`, `Hive/App/LevelLoader.swift`, `Hive/Rendering/Typography.swift`, `Hive/Rendering/Button.swift`, `Hive/Rendering/Shapes.swift`
- Modify: `Hive/App/AppDelegate.swift`, `Hive/App/GameViewController.swift` (delete; `SceneDelegate` owns the `SKView` in a plain `UIViewController`), `Hive/Resources/Info.plist`, `Hive/Scenes/GameScene.swift`, `Hive/Rendering/EndOverlay.swift`, `Hive/Rendering/HUDNode.swift`, `Hive/Rendering/CardPickOverlay.swift`, `Hive/Rendering/PauseOverlay.swift`, `Hive/Rendering/HiveNode.swift`, `Hive/Rendering/MobNode.swift` (use `Shapes.hexPath`)

**Interfaces:**
- Consumes: `GameState`, `FileSaveStore`, `RunResult`, `CoinRules`, `World(level:hiveStats:cardPool:startingCardCount:seed:)`, `World.runID`.
- Produces:
  ```swift
  enum Typography { static let font = "AvenirNext-DemiBold"; static let title: CGFloat = 30; static let body: CGFloat = 15; static let small: CGFloat = 12 }
  enum Shapes { static func hexPath(circumradius: CGFloat, pointyTop: Bool = false) -> CGPath; static func roundedRect(_ size: CGSize, corner: CGFloat) -> CGPath }
  final class Button: SKNode { init(title: String, name: String, size: CGSize = CGSize(width: 220, height: 52), style: Style /* .filled (amber bg, dark text) | .outlined (amber stroke, gold text) */); var isEnabled: Bool /* dims to alpha 0.35 and ignores hits */; func contains(_ point: CGPoint) -> Bool }
  struct LevelLoader { init(bundle: Bundle = .main); func availableLevelIDs() -> [Int] /* level_001…, stops at the first missing */; func load(id: Int) throws -> LevelDefinition }
  final class AppFlow {
      init(view: SKView, store: SaveStore, levels: LevelLoader)
      private(set) var state: GameState
      func start()                         // load (corrupt → fresh + log) then showHome()
      func showHome(); func showUpgrades(); func showLevelSelect()
      func startLevel(id: Int)             // builds stats/cardPool/startingCardCount from state, presents GameScene
      func runEnded(_ result: RunResult)   // state.record; if it returned true, store.save; (Review Focus 4)
      func purchase(_ track: UpgradeTrack) -> Bool   // state.purchase; save on success
      func makeRunResult(world: World, levelId: Int) -> RunResult   // uses CoinRules with state.upgrades.coinMultiplier
  }
  ```
  - `GameScene`: `init(level: LevelDefinition, levelId: Int, stats: HiveStats, cardPool: [UpgradeCard], startingCardCount: Int, flow: AppFlow, size: CGSize)`; `didMove` builds HUD/hive once and calls `startRun()`; on `.cleared`/`.gameOver` it calls `flow.runEnded(flow.makeRunResult(world:levelId:))` **once per world** (guard by `world.runID` stored in `lastReportedRunID`), then presents `EndOverlay(result:)`.
  - `EndOverlay(result: RunResult, viewSize:, onContinue: (() -> Void)?, onRetry: () -> Void, onHome: () -> Void)`: title as before; subtitle `Reached wave N`; coins line `+80 coins` in gold 22 pt; buttons stacked: CONTINUE (filled, only when cleared and a next level exists), RETRY / PLAY AGAIN (outlined), HOME (outlined). Names `continue`, `retry`, `home`.
  - `HUDNode.update(...)` gains `coinsPending: Int` shown top-left as `◆ 24` in gold 14 pt (the run's provisional coins via `CoinRules.coins(levelId:wavesCleared: waveNumber-1, cleared: false, multiplier:)`).
  - `SceneDelegate`: creates `UIWindow(windowScene:)`, a `UIViewController` whose view is an `SKView` (`ignoresSiblingOrder`, DEBUG fps/node counts), builds `FileSaveStore(directory: <Application Support>/Hive)`, `LevelLoader()`, `AppFlow`, calls `flow.start()`. `Info.plist` gains `UIApplicationSceneManifest` with one `UIWindowSceneSessionRoleApplication` config pointing at `$(PRODUCT_MODULE_NAME).SceneDelegate`; `AppDelegate` keeps only `@main` and `configurationForConnecting`.
  - A **placeholder `HomeScene`** in this task: dark background, `HOME` label, coin balance, one PLAY button calling `flow.startLevel(id: state.currentLevel)` (clamped to available levels). Task 6 replaces it.

- [ ] **Step 1: Implement** all of the above. Replace every `hexPath` with `Shapes.hexPath` and every font literal with `Typography.font`.
- [ ] **Step 2: Build** (Global Constraints command). Expected `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Verify on the simulator** — launch: placeholder home with `◆ 0`; tap PLAY; play until the run ends (choose cards); end overlay shows `+N coins` and HOME; tap HOME → home shows the new balance. Tap PLAY again, let it end, tap RETRY → a fresh run; end it, tap HOME → balance increased by both runs. Kill the app (`xcrun simctl terminate 2B4C8064-73B0-48D3-8246-1CA9711ED4D3 com.lwilliams.hive`), relaunch → balance persists. Screenshots `m2-t4-home.png`, `m2-t4-end.png`.
- [ ] **Step 4: Commit** — `feat(app): app flow with UIScene lifecycle, save store, coins on results, parameterized game scene`.

---

### Task 5: HiveRenderer (visual tiers 1…11)

**Files:**
- Create: `Hive/Rendering/HiveRenderer.swift`
- Modify: `Hive/Scenes/GameScene.swift` (use the renderer at `flow.state.upgrades.visualTier`); delete `Hive/Rendering/HiveNode.swift`.

**Interfaces:**
- Produces: `enum HiveRenderer { static func makeHive(visualTier: Int) -> SKNode }` with `visualTier` clamped 1…11. Node origin at hive center; everything inside a radius of about 110 pt at tier 11, 32 pt at tier 1 (so `Hive.radius = 40` still matches the playable silhouette at low tiers; higher tiers are allowed to look bigger than the hit radius).
- Geometry: honeycomb of **pointy-top** hexes, cell circumradius `r = 13`, neighbor distance `√3·r`; rings 0,1,2,3 have 1, 6, 12, 18 cells. Cells are `SKShapeNode(path: Shapes.hexPath(circumradius: r, pointyTop: true))`, `fillColor` amber (center cell gold), `strokeColor` burnt orange, `lineWidth 1`, **`glowWidth 0`** (crisp). One ambient glow behind: `SKShapeNode(circleOfRadius:)` with `fillColor` amber alpha 0.06, **`strokeColor` amber alpha 0.22**, `glowWidth` 14 + 2·tier, radius 36 + 7·tier, pulsing scale 1.0→1.05 over 1.6 s forever.
- Tier table (cumulative):

| v | cells | extras |
|---|---|---|
| 1 | center + 4 of ring 1 (skip indices 1 and 4), cells alpha 0.75 | glow dim |
| 2 | full ring 1 (7) | cell alpha 0.85 |
| 3 | + ring 2 even indices (6) | alpha 1 |
| 4 | full ring 2 (19) | |
| 5 | same | **wax wall**: stroked pointy-top hexagon, circumradius `4.2·r`, stroke burnt orange alpha 0.9, lineWidth 3, no fill |
| 6 | + ring 3 indices divisible by 3 (6) | |
| 7 | full ring 3 (37) | |
| 8 | same | **honey channels**: 6 lines from center to the ring-3 corner cells, gold alpha 0.5, lineWidth 2, pulsing alpha 0.3↔0.7 over 1.2 s |
| 9 | same | second wall at `5.4·r`, gold alpha 0.6, lineWidth 2; glow stroke alpha 0.3 |
| 10 | same | **queen chamber**: center cell replaced by a gold hex of circumradius `1.6·r` with a white alpha 0.35 inner hex of `0.7·r` |
| 11 | same | **crown**: three small gold triangles (side 8) along the top edge of the queen chamber; glow stroke alpha 0.4 |

- [ ] **Step 1: Implement** `HiveRenderer` per the table; `GameScene` uses it; delete `HiveNode.swift`.
- [ ] **Step 2: Build** and verify on the simulator: launch, play, screenshot the tier-1 hive at the game's 1× scale (`m2-t5-tier1.png`). Visual check: crisp hex edges, soft ambient halo, nothing blurry, no faces. (Tiers 2–11 are verified in Task 7 via the upgrades preview.)
- [ ] **Step 3: Commit** — `feat(app): hive renderer with 11 visual tiers; crisp cells, ambient glow`.

---

### Task 6: Home scene

**Files:**
- Create: `Hive/Scenes/HomeScene.swift` (replaces the Task 4 placeholder)

**Interfaces:**
- Consumes: `AppFlow` (`state`, `showUpgrades`, `showLevelSelect`, `startLevel`), `HiveRenderer`, `Button`, `LevelLoader.availableLevelIDs()`.
- Layout (portrait, centered anchor; `h = size.height`): coin balance top-left `◆ 1,240` (grouping separator) gold 16 pt at `(−w/2+24, h/2−52)`; hive via `HiveRenderer.makeHive(visualTier:)` at `(0, h·0.14)` scaled `1.8` for tiers 1–4, `1.4` for 5–8, `1.1` for 9–11; level label under it `LEVEL 3` gold alpha 0.8 14 pt (current level); buttons stacked from `y = −h·0.12` downward with 16 pt gaps: PLAY (filled; disabled if no level available), LEVELS (outlined), UPGRADES (outlined), ENDLESS (outlined, `isEnabled = false`, subtitle "Unlocks after level 10" 11 pt alpha 0.6). Title word `HIVE` 12 pt letter-spaced gold alpha 0.5 at the very top center.
- Hive on Home gets a slow idle rotation `SKAction.rotate(byAngle: 2π, duration: 240)` forever (subtle life).

- [ ] **Step 1: Implement** `HomeScene`; `AppFlow.showHome()` presents it with `SKTransition.fade(withDuration: 0.3)`.
- [ ] **Step 2: Build**, verify: home shows coins, hive, level, four buttons with ENDLESS dimmed; PLAY starts the current level; HOME from the end overlay returns. Screenshot `m2-t6-home.png`.
- [ ] **Step 3: Commit** — `feat(app): home scene with hive, coins, play/levels/upgrades`.

---

### Task 7: Upgrades scene with live hive preview

**Files:**
- Create: `Hive/Scenes/UpgradesScene.swift`

**Interfaces:**
- Consumes: `AppFlow.purchase(_:)`, `flow.state`, `PermanentUpgrades` (`tier(of:)`, `nextCost(for:)`, `effectDescription(for:atTier:)`, `visualTier`), `HiveRenderer`, `Button`.
- Layout: top bar: BACK (outlined, 100×40, name `back`) at top-left, coin balance top-right. Hive preview at `(0, h/2 − 190)` scaled 1.0, rebuilt whenever a purchase changes `visualTier` (with a 0.25 s scale-pop 1.0→1.12→1.0). Below it a label `TIER v / 11 · next look at N more tiers`. Five **rows** (not columns; portrait): each row 360×64 with `fill #15120C`, stroke amber alpha 0.4, corner 12: left: track `displayName` 16 pt white and `summary` 11 pt gold alpha 0.7; middle: ten 10×10 tier pips (filled gold for owned tiers, outlined burnt orange otherwise); right: a 96×36 BUY button (filled) labeled with the cost `◆ 140`, `isEnabled = state.canAfford(track)`, or `MAX` outlined-disabled at tier 10. Under the row name, `effectDescription(for:atTier: tier+1)` preview in 11 pt alpha 0.6 (what you'd get). Row node names `buy:<track>`.
- Tap on BUY: `flow.purchase(track)`; on success re-render the row set, coin label, and the hive preview if `visualTier` changed; on failure a brief 0.2 s shake of the coin label.
- `AppFlow.showUpgrades()` presents it; BACK → `flow.showHome()`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Build**, verify on the simulator: with a saved balance (play a few runs first, or give yourself coins by editing the save at `~/Library/Developer/CoreSimulator/Devices/2B4C8064-73B0-48D3-8246-1CA9711ED4D3/data/Containers/Data/Application/<app>/Library/Application Support/Hive/save.json` to `"coins": 20000` for this verification only) buy tiers across tracks and screenshot the hive preview at visual tiers 2, 5, 8, 10 and 11 (`m2-t7-tier2.png` … `m2-t7-tier11.png`). Check each against the Task 5 table and spec 5.5 ("glowing geometric city" at the top). Confirm a BUY at insufficient coins is dimmed and does nothing. Kill and relaunch: tiers persist.
- [ ] **Step 3: Commit** — `feat(app): upgrades scene with five tracks and live hive preview`.

---

### Task 8: Level select, continue flow, balance probe at mid-game, README

**Files:**
- Create: `Hive/Scenes/LevelSelectScene.swift`
- Modify: `HiveCore/Tests/HiveCoreTests/BalanceProbeTests.swift`, `README.md`, `Hive/App/AppFlow.swift` (continue to next level from the results overlay)

**Interfaces:**
- `LevelSelectScene`: BACK top-left, title `LEVELS`; a vertical list of rows (one per `availableLevelIDs()`), 300×56, 12 pt gap, scrollable by vertical drag when taller than the view (translate a container node, clamped): `LEVEL 1 · First Light` (name from the JSON) with state tag `CLEARED` (gold), `CURRENT` (white), `LOCKED` (alpha 0.35, not tappable). Tap → `flow.startLevel(id:)`. Row names `level:<id>`.
- `EndOverlay` CONTINUE: `flow.startLevel(id: result.levelId + 1)` when that level exists.
- Balance probe: add `testGreedyPolicyAtMidGameUpgradesClearsLevelOneReliably`: stats from `PermanentUpgrades(tiers: [.comb: 3, .stinger: 3, .swarm: 3, .nectar: 0, .queen: 3])` (`startingCardCount 1`), greedy policy, seeds 1…20 → `cleared ≥ 17`. This pins that permanent progress actually turns level 1 into a sure thing, as spec 5.3 intends. Do not retune level 1 for this; if it fails, the stat derivation constants in Task 1 are too weak and the controller must rule.
- README: add Home/Upgrades/Levels flow, the save file location and corrupt-file behavior, the upgrade tables (costs, stat formulas), and the new probe.

- [ ] **Step 1: Implement** the scene, the continue path, the probe test, the README.
- [ ] **Step 2: Run** `cd HiveCore && swift test 2>&1 | grep -E "BalanceProbe|Executed"` → 66 tests, 0 failures, three probe lines.
- [ ] **Step 3: Build**, verify: LEVELS shows level 1 as CURRENT; after clearing it the end overlay has no CONTINUE (only one level exists) and LEVELS shows level 1 as CLEARED; screenshot `m2-t8-levels.png`. Full loop: home → play → results → home → upgrades → buy → home → play (hive looks different, run feels stronger).
- [ ] **Step 4: Commit** — `feat: level select, continue flow, mid-game balance probe, README (milestone 2 progression)`.

---

## Self-review notes

- **Spec coverage (milestone 2):** coins ✔ (T2, T4), home screen with hive at tier and buttons ✔ (T6; Settings deferred to M5 with ATT; Endless shown locked, M3), upgrades screen five tracks with live preview ✔ (T7), hive visuals changing per tier ✔ (T5 table, verified T7), level select ✔ (T8), save/load ✔ (T2, T4), results screen with continue/retry/home ✔ (T4; double-coins/revive ad buttons are M4), coin count on the game HUD ✔ (T4). Queen "revive chance" is M4 (ads); queen in M2 is starting cards only, per Global Constraints.
- **Deferred M1 items closed here:** UIScreen.main/UIScene (T4), didMove duplication (T4 startRun from didMove once), seed/world creation duplicated (T4 AppFlow builds worlds), overlay downcasts (already a protocol; Button added), font repeated (Typography, T4), hexPath duplicated (Shapes, T4), glow strokes clear and blurry honeycomb (T5), duplicate `level` copy in World (left; harmless), choose/HP-card tests (T3 covers pool; HP-card choose test added to T3 as `testStartingCardsAppliedAtInit` exercises apply through World).
- **Type consistency:** `PermanentUpgrades.visualTier` used by T5/T6/T7; `AppFlow.purchase` returns Bool used by T7; `RunResult` fields used by `EndOverlay` and `GameState.record`; `World.runID` used by `GameScene.lastReportedRunID`; `LevelLoader.availableLevelIDs()` used by T4/T6/T8.
- **Review Focus:** each item names its test or simulator check in the owning task.
- **Proportion:** ~1.4× the M1 plan with far more surface; tests are listed as names plus assertions, not full code, since the M1 harness conventions are established in the repo.
