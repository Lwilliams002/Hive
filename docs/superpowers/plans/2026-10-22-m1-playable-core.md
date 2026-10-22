# Hive — Milestone 1: Playable Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable iOS build where a hive at screen center auto-fires at mobs spawned by a JSON level script, the player picks one of three upgrade cards when the nectar bar fills, and the level ends in "cleared" or "game over" with a retry button, all visible in the iOS Simulator.

**Architecture:** All game logic lives in a pure-Swift package `HiveCore` (no SpriteKit import) built around a `World` value type advanced by `tick(dt:)` that returns a list of `GameEvent`s. The iOS app target `Hive` owns a `World`, ticks it from `SKScene.update`, and reconciles SpriteKit nodes against the world's entities by id. Logic is tested with `swift test`; rendering is verified in the simulator.

**Tech Stack:** Swift 5 language mode on the Swift 6.2 toolchain, SpriteKit, UIKit host, XcodeGen for the project file, XCTest, iOS 16 minimum. No third-party dependencies in this milestone.

**Spec:** `docs/superpowers/specs/2026-10-22-hive-defense-design.md` (sections 5.1, 5.3, 5.4 run cards, 5.5, 5.6 screen 4/5/6, 7, 8 milestone 1).

## Global Constraints

- iOS deployment target **16.0**; device family iPhone; portrait only.
- Swift language mode **5** (`SWIFT_VERSION = 5.0`, `swiftLanguageVersions: [.v5]`) to avoid Swift 6 strict-concurrency friction in SpriteKit code.
- `HiveCore` must not import SpriteKit, UIKit, or Foundation types beyond `Foundation` basics (`Codable`, `TimeInterval`, `Data`, `JSONDecoder`).
- All randomness in `HiveCore` goes through `SeededRNG`; no `Int.random` / `shuffled()` without the seeded generator.
- Simulation uses a **fixed timestep**: `World.tick(dt:)` receives `dt` clamped by the caller to at most `1.0/30.0`.
- World coordinates: origin at hive center, 1 unit = 1 point. Hive radius **40**. Mob spawn radius **520** (off-screen on an iPhone 17 Pro Max 440×956 pt portrait view).
- Visual rules from spec 5.5: background near-black `#0B0A08`; hive amber `#E8A33C` / gold `#F2C14E` / burnt orange `#B8641B`; mobs slate `#5E6B7A`, violet `#7A4FA3`, sickly green `#6E8B3D`; projectiles and hit flash white. No faces, no cartoon palette.
- Commit after every task; commit messages in `type: summary` form; end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Project root: `/Users/lezdev/Desktop/Williams/ad-game`.

## Review Focus

1. **`dt` of 0 or a huge `dt`** (app backgrounded, first frame): the world must not divide by zero, teleport mobs through the hive, or fire a burst of projectiles. Pinned in Task 4 (`testTickWithZeroDtChangesNothing`, caller clamps in Task 7).
2. **Mob and hive contact in the same tick a projectile kills it**: the mob must not both die and deal contact damage. Pinned in Task 4 (`testKilledMobDoesNotDealContactDamage`).
3. **Nectar overflow across a threshold while already picking cards**: a second pick must not be queued or lost; excess nectar carries over. Pinned in Task 5 (`testNectarCarriesOverAfterThreshold`, `testTickWhilePickingIsNoOp`).
4. **Level JSON missing or malformed**: the app must fail loudly at load with a clear error, not spawn nothing forever. Pinned in Task 3 (`testMalformedLevelJSONThrows`) and Task 8 (fatalError with message on load failure, verified in simulator logs by renaming the file).
5. **Last mob dies by contact damage on the boss wave**: the run must resolve to exactly one terminal phase (cleared *or* game over), never both. Pinned in Task 4 (`testBossWaveClearedByContactStillResolvesOnce`).

---

## File Structure

```
ad-game/
  .gitignore
  project.yml                              XcodeGen spec → Hive.xcodeproj (generated, ignored)
  HiveCore/
    Package.swift
    Sources/HiveCore/
      Math/Vec2.swift                      2D vector value type
      Math/SeededRNG.swift                 SplitMix64 RandomNumberGenerator
      Entities/Hive.swift                  HiveStats + Hive (hp, cooldown)
      Entities/Mob.swift                   MobType catalog + Mob instance
      Entities/Projectile.swift
      Waves/LevelDefinition.swift          Codable JSON model
      Waves/WaveDirector.swift             turns LevelDefinition into timed spawns
      Upgrades/UpgradeCard.swift           card ids, rarity, effect enum
      Upgrades/UpgradeCatalog.swift        the 6 milestone-1 cards + weighted draw
      Upgrades/NectarMeter.swift           thresholds, fill, overflow
      World/GameEvent.swift
      World/RunPhase.swift
      World/World.swift                    tick(dt:), choose(card:), targeting, collision
    Tests/HiveCoreTests/
      Vec2Tests.swift
      SeededRNGTests.swift
      MobTests.swift
      LevelDefinitionTests.swift
      WaveDirectorTests.swift
      WorldCombatTests.swift
      NectarAndCardsTests.swift
      RunPhaseTests.swift
      Fixtures/level_test.json
  Hive/
    App/AppDelegate.swift
    App/GameViewController.swift           hosts SKView, presents GameScene
    Scenes/GameScene.swift                 owns World, ticks, reconciles nodes, routes taps
    Rendering/Palette.swift                UIColor constants from Global Constraints
    Rendering/HiveNode.swift               hex-cluster hive at tier 1
    Rendering/MobNode.swift                shape per MobType
    Rendering/ProjectileNode.swift
    Rendering/HUDNode.swift                hp bar, wave label, nectar bar
    Rendering/CardPickOverlay.swift        three tappable cards
    Rendering/EndOverlay.swift             cleared / game over + retry
    Resources/Levels/level_001.json
    Resources/Assets.xcassets/             AppIcon placeholder, AccentColor
    Resources/LaunchScreen.storyboard
    Resources/Info.plist
```

Dependency order: Task 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8. Tasks 2–5 are `swift test` only; Tasks 6–8 need the simulator.

---

### Task 1: Project skeleton (package, app target, dark screen on the simulator)

**Files:**
- Create: `.gitignore`, `project.yml`, `HiveCore/Package.swift`, `HiveCore/Sources/HiveCore/Math/Vec2.swift`, `HiveCore/Tests/HiveCoreTests/Vec2Tests.swift`, `Hive/App/AppDelegate.swift`, `Hive/App/GameViewController.swift`, `Hive/Scenes/GameScene.swift`, `Hive/Rendering/Palette.swift`, `Hive/Resources/Info.plist`, `Hive/Resources/LaunchScreen.storyboard`, `Hive/Resources/Assets.xcassets/Contents.json`

**Interfaces:**
- Produces: `public struct Vec2: Equatable { var x, y: Double; init(_ x: Double, _ y: Double); static let zero; static func +, -, * (Vec2, Double); var length: Double; var normalized: Vec2; func distance(to: Vec2) -> Double }`
- Produces: `enum Palette` with `static let background, amber, gold, burntOrange, slate, violet, sicklyGreen, white: UIColor` (hex values from Global Constraints).
- Produces: `final class GameScene: SKScene` presented by `GameViewController` in portrait, `scaleMode = .resizeFill`, `anchorPoint = (0.5, 0.5)`, background `Palette.background`.
- Produces: build command used by every later task:
  `xcodebuild -project Hive.xcodeproj -scheme Hive -destination 'platform=iOS Simulator,id=2B4C8064-73B0-48D3-8246-1CA9711ED4D3' -derivedDataPath build build`
  producing `build/Build/Products/Debug-iphonesimulator/Hive.app`, bundle id `com.lwilliams.hive`.

- [ ] **Step 1: Install XcodeGen and init git**

Run: `brew install xcodegen && cd /Users/lezdev/Desktop/Williams/ad-game && git init -b main`
Expected: `xcodegen --version` prints a version; `.git` exists.

- [ ] **Step 2: Write `.gitignore`**

Ignore: `Hive.xcodeproj/`, `build/`, `.build/`, `DerivedData/`, `*.xcuserstate`, `.DS_Store`, `Hive/Resources/AdConfig.plist` (reserved for real AdMob ids, milestone 4).

- [ ] **Step 3: Write `HiveCore/Package.swift`**

`swift-tools-version:5.9`, name `HiveCore`, platforms `[.iOS(.v16), .macOS(.v13)]` (macOS so `swift test` runs on the host), one library target `HiveCore`, one test target `HiveCoreTests` with `resources: [.copy("Fixtures")]`, `swiftLanguageVersions: [.v5]`.

- [ ] **Step 4: Write the failing Vec2 test**

```swift
// HiveCore/Tests/HiveCoreTests/Vec2Tests.swift
import XCTest
@testable import HiveCore

final class Vec2Tests: XCTestCase {
    func testLengthAndNormalized() {
        let v = Vec2(3, 4)
        XCTAssertEqual(v.length, 5, accuracy: 1e-9)
        XCTAssertEqual(v.normalized.x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(v.normalized.y, 0.8, accuracy: 1e-9)
    }
    func testNormalizedOfZeroIsZero() {
        XCTAssertEqual(Vec2.zero.normalized, .zero)
    }
    func testDistance() {
        XCTAssertEqual(Vec2(1, 1).distance(to: Vec2(4, 5)), 5, accuracy: 1e-9)
    }
}
```

- [ ] **Step 5: Run to verify it fails**

Run: `cd HiveCore && swift test 2>&1 | tail -5`
Expected: compile error, `cannot find 'Vec2' in scope`.

- [ ] **Step 6: Implement `Vec2` in `HiveCore/Sources/HiveCore/Math/Vec2.swift`** with the interface above. `normalized` of a zero-length vector returns `.zero`.

- [ ] **Step 7: Run to verify it passes**

Run: `cd HiveCore && swift test 2>&1 | tail -3`
Expected: `Executed 3 tests, with 0 failures`.

- [ ] **Step 8: Write `project.yml`**

```yaml
name: Hive
options:
  bundleIdPrefix: com.lwilliams
  deploymentTarget:
    iOS: "16.0"
  xcodeVersion: "26.2"
packages:
  HiveCore:
    path: HiveCore
targets:
  Hive:
    type: application
    platform: iOS
    sources: [Hive]
    dependencies:
      - package: HiveCore
    settings:
      base:
        SWIFT_VERSION: "5.0"
        PRODUCT_BUNDLE_IDENTIFIER: com.lwilliams.hive
        INFOPLIST_FILE: Hive/Resources/Info.plist
        TARGETED_DEVICE_FAMILY: "1"
        CODE_SIGN_IDENTITY: ""
        CODE_SIGNING_REQUIRED: "NO"
        CODE_SIGNING_ALLOWED: "NO"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

- [ ] **Step 9: Write the app host files**

- `Info.plist`: `UILaunchStoryboardName = LaunchScreen`, `UISupportedInterfaceOrientations = [UIInterfaceOrientationPortrait]`, `UIRequiresFullScreen = YES`, `UIStatusBarHidden = YES`, `UIViewControllerBasedStatusBarAppearance = NO`, `CFBundleDisplayName = Hive`, standard `CFBundle*` keys using `$(…)` build settings.
- `LaunchScreen.storyboard`: a single view controller with background color `#0B0A08`.
- `Assets.xcassets/Contents.json` plus an empty `AppIcon.appiconset` (icon itself is milestone 5).
- `AppDelegate.swift`: `@main`, creates `UIWindow`, root `GameViewController`. No storyboard for main.
- `Palette.swift`: the eight colors as `UIColor(red:green:blue:alpha:)` from the hex values in Global Constraints.
- `GameViewController.swift`: `loadView` creates an `SKView`; `viewDidLoad` presents `GameScene(size: view.bounds.size)` with `scaleMode = .resizeFill`; `ignoresSiblingOrder = true`; `showsFPS` and `showsNodeCount` on in DEBUG; `supportedInterfaceOrientations = .portrait`; `prefersStatusBarHidden = true`.
- `GameScene.swift`: `didMove(to:)` sets `anchorPoint = CGPoint(x: 0.5, y: 0.5)` and `backgroundColor = Palette.background`. Nothing else yet.

- [ ] **Step 10: Generate and build**

Run: `cd /Users/lezdev/Desktop/Williams/ad-game && xcodegen generate && xcodebuild -project Hive.xcodeproj -scheme Hive -destination 'platform=iOS Simulator,id=2B4C8064-73B0-48D3-8246-1CA9711ED4D3' -derivedDataPath build build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 11: Launch in the simulator and verify**

Launch `build/Build/Products/Debug-iphonesimulator/Hive.app` on the booted iPhone 17 Pro Max with the iOS Simulator tool (`launch`, then `screenshot`).
Expected: a full-screen near-black view, FPS counter visible bottom-right, no crash in `xcrun simctl spawn booted log stream --predicate 'process == "Hive"' --style compact` for 5 seconds.

- [ ] **Step 12: Commit**

```bash
git add -A && git commit -m "chore: scaffold Hive app target and HiveCore package with Vec2"
```

---

### Task 2: Seeded RNG and mob catalog

**Files:**
- Create: `HiveCore/Sources/HiveCore/Math/SeededRNG.swift`, `HiveCore/Sources/HiveCore/Entities/Mob.swift`
- Test: `HiveCore/Tests/HiveCoreTests/SeededRNGTests.swift`, `HiveCore/Tests/HiveCoreTests/MobTests.swift`

**Interfaces:**
- Produces: `public struct SeededRNG: RandomNumberGenerator { public init(seed: UInt64); public mutating func next() -> UInt64; public mutating func unitDouble() -> Double /* [0,1) */ }` (SplitMix64).
- Produces:
  ```swift
  public enum MobType: String, Codable, CaseIterable { case wasp, hornet, bear }
  public struct MobStats: Equatable { public let maxHP, speed, contactDamage, radius: Double; public let nectar: Int; public let isBoss: Bool }
  public extension MobType { var stats: MobStats }
  public struct Mob: Identifiable, Equatable { public let id: Int; public let type: MobType; public var position: Vec2; public var hp: Double; public var hitFlash: Double /* seconds remaining, rendering hint */ }
  ```
- Stats table (spec 5.5 silhouettes; numbers are this plan's tuning, builder may not change in this milestone so Task 8 tuning is reproducible):

| type | maxHP | speed (pt/s) | contactDamage | radius | nectar | boss |
|---|---|---|---|---|---|---|
| wasp | 20 | 90 | 10 | 10 | 1 | no |
| hornet | 60 | 55 | 20 | 14 | 3 | no |
| bear | 450 | 28 | 40 | 30 | 15 | yes |

- [ ] **Step 1: Write the failing tests**

```swift
// SeededRNGTests.swift
final class SeededRNGTests: XCTestCase {
    func testSameSeedSameSequence() {
        var a = SeededRNG(seed: 42), b = SeededRNG(seed: 42)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }
    func testDifferentSeedsDiffer() {
        var a = SeededRNG(seed: 1), b = SeededRNG(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }
    func testUnitDoubleInRange() {
        var r = SeededRNG(seed: 7)
        for _ in 0..<1000 { let d = r.unitDouble(); XCTAssert(d >= 0 && d < 1) }
    }
}
// MobTests.swift
final class MobTests: XCTestCase {
    func testStatsTable() {
        XCTAssertEqual(MobType.wasp.stats, MobStats(maxHP: 20, speed: 90, contactDamage: 10, radius: 10, nectar: 1, isBoss: false))
        XCTAssertEqual(MobType.hornet.stats, MobStats(maxHP: 60, speed: 55, contactDamage: 20, radius: 14, nectar: 3, isBoss: false))
        XCTAssertEqual(MobType.bear.stats, MobStats(maxHP: 450, speed: 28, contactDamage: 40, radius: 30, nectar: 15, isBoss: true))
    }
    func testMobDecodesFromRawValue() {
        XCTAssertEqual(try JSONDecoder().decode(MobType.self, from: Data("\"hornet\"".utf8)), .hornet)
    }
}
```

- [ ] **Step 2: Run to verify they fail** — `cd HiveCore && swift test 2>&1 | grep -E "error|Executed" | head`. Expected: compile errors for `SeededRNG`, `MobType`.

- [ ] **Step 3: Implement `SeededRNG` (SplitMix64)** in `Math/SeededRNG.swift`. `unitDouble()` = `Double(next() >> 11) * 0x1.0p-53`.

- [ ] **Step 4: Implement `MobType`, `MobStats`, `Mob`** in `Entities/Mob.swift` with the table above. `Mob.init(id:type:position:)` sets `hp = type.stats.maxHP`, `hitFlash = 0`.

- [ ] **Step 5: Run to verify pass** — `swift test 2>&1 | tail -2`. Expected: `Executed 8 tests, with 0 failures`.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(core): seeded RNG and mob catalog"`

---

### Task 3: Level definition JSON and wave director

**Files:**
- Create: `HiveCore/Sources/HiveCore/Waves/LevelDefinition.swift`, `HiveCore/Sources/HiveCore/Waves/WaveDirector.swift`, `HiveCore/Tests/HiveCoreTests/Fixtures/level_test.json`
- Test: `HiveCore/Tests/HiveCoreTests/LevelDefinitionTests.swift`, `HiveCore/Tests/HiveCoreTests/WaveDirectorTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct SpawnGroup: Codable, Equatable { public let type: MobType; public let count: Int; public let interval: Double /* seconds between spawns in this group */ }
  public struct WaveDefinition: Codable, Equatable { public let delay: Double /* seconds after previous wave is cleared (or level start) */; public let isBoss: Bool /* default false */; public let spawns: [SpawnGroup] }
  public struct LevelDefinition: Codable, Equatable {
      public let id: Int; public let name: String; public let waves: [WaveDefinition]
      public static func load(from data: Data) throws -> LevelDefinition   // JSONDecoder; throws LevelError.invalid(String) on empty waves or a wave with no spawns
  }
  public enum LevelError: Error, Equatable { case invalid(String) }

  public struct WaveDirector: Equatable {
      public init(level: LevelDefinition)
      public var currentWaveIndex: Int        // 0-based; == waves.count when all waves have been issued
      public var waveNumber: Int              // 1-based for HUD, min(currentWaveIndex+1, waves.count)
      public var totalWaves: Int
      public var isBossWave: Bool
      /// Advance the clock. `aliveMobs` is the count of mobs currently alive in the world.
      /// Returns the MobTypes to spawn this tick. Starts the next wave only when the current
      /// wave has issued all its spawns, `aliveMobs == 0`, and that wave's `delay` has elapsed.
      public mutating func tick(dt: Double, aliveMobs: Int) -> [MobType]
      public var allSpawnsIssued: Bool        // true when the last wave has issued every spawn
  }
  ```
- Spawn groups within one wave run **concurrently**, each on its own interval; the first spawn of each group fires at the moment the wave starts (`interval` applies between subsequent spawns). `interval == 0` issues the whole group at once.

- [ ] **Step 1: Write the fixture `Fixtures/level_test.json`**

```json
{ "id": 99, "name": "Test", "waves": [
  { "delay": 1.0, "spawns": [ { "type": "wasp", "count": 3, "interval": 0.5 } ] },
  { "delay": 2.0, "isBoss": true, "spawns": [ { "type": "bear", "count": 1, "interval": 0 }, { "type": "wasp", "count": 2, "interval": 1.0 } ] }
] }
```

- [ ] **Step 2: Write the failing tests**

```swift
// LevelDefinitionTests.swift
final class LevelDefinitionTests: XCTestCase {
    func fixture() throws -> Data {
        let url = Bundle.module.url(forResource: "level_test", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }
    func testDecodesFixture() throws {
        let level = try LevelDefinition.load(from: fixture())
        XCTAssertEqual(level.id, 99)
        XCTAssertEqual(level.waves.count, 2)
        XCTAssertFalse(level.waves[0].isBoss)
        XCTAssertTrue(level.waves[1].isBoss)
        XCTAssertEqual(level.waves[1].spawns[0], SpawnGroup(type: .bear, count: 1, interval: 0))
    }
    func testMalformedLevelJSONThrows() {
        XCTAssertThrowsError(try LevelDefinition.load(from: Data("{not json".utf8)))
    }
    func testEmptyWavesThrowsInvalid() {
        let data = Data(#"{"id":1,"name":"x","waves":[]}"#.utf8)
        XCTAssertThrowsError(try LevelDefinition.load(from: data)) { XCTAssertEqual($0 as? LevelError, .invalid("level 1 has no waves")) }
    }
}
// WaveDirectorTests.swift
final class WaveDirectorTests: XCTestCase {
    var level: LevelDefinition { try! LevelDefinition.load(from: try! Data(contentsOf: Bundle.module.url(forResource: "level_test", withExtension: "json", subdirectory: "Fixtures")!)) }
    func testNothingSpawnsBeforeFirstDelay() {
        var d = WaveDirector(level: level)
        XCTAssertEqual(d.tick(dt: 0.9, aliveMobs: 0), [])
        XCTAssertEqual(d.waveNumber, 1); XCTAssertEqual(d.totalWaves, 2)
    }
    func testFirstGroupSpawnsOnIntervalFromWaveStart() {
        var d = WaveDirector(level: level)
        XCTAssertEqual(d.tick(dt: 1.0, aliveMobs: 0), [.wasp])     // wave starts, first spawn immediate
        XCTAssertEqual(d.tick(dt: 0.4, aliveMobs: 1), [])
        XCTAssertEqual(d.tick(dt: 0.1, aliveMobs: 1), [.wasp])
        XCTAssertEqual(d.tick(dt: 0.5, aliveMobs: 2), [.wasp])
        XCTAssertEqual(d.tick(dt: 5.0, aliveMobs: 3), [])          // all issued, mobs alive → no next wave
        XCTAssertFalse(d.isBossWave)
    }
    func testNextWaveWaitsForClearThenDelay() {
        var d = WaveDirector(level: level)
        _ = d.tick(dt: 1.0, aliveMobs: 0); _ = d.tick(dt: 1.0, aliveMobs: 1)   // wave 1 fully issued
        XCTAssertEqual(d.tick(dt: 1.9, aliveMobs: 0), [])           // delay 2.0 not yet elapsed
        let spawned = d.tick(dt: 0.1, aliveMobs: 0)
        XCTAssertEqual(Set(spawned), Set([.bear, .wasp]))           // interval-0 group + first of wasp group
        XCTAssertTrue(d.isBossWave); XCTAssertEqual(d.waveNumber, 2)
    }
    func testAllSpawnsIssued() {
        var d = WaveDirector(level: level)
        _ = d.tick(dt: 1.0, aliveMobs: 0); _ = d.tick(dt: 1.0, aliveMobs: 1)
        _ = d.tick(dt: 2.0, aliveMobs: 0); _ = d.tick(dt: 1.0, aliveMobs: 3)
        XCTAssertTrue(d.allSpawnsIssued)
        XCTAssertEqual(d.tick(dt: 10, aliveMobs: 0), [])
    }
}
```

- [ ] **Step 3: Run to verify fail** — `swift test 2>&1 | grep -E "error:" | head -3`. Expected: unresolved `LevelDefinition`, `WaveDirector`.

- [ ] **Step 4: Implement `LevelDefinition.swift`**. `isBoss` decodes with `decodeIfPresent ?? false`. `load` validates: empty `waves` → `.invalid("level \(id) has no waves")`; any wave with empty `spawns` → `.invalid("level \(id) wave \(i) has no spawns")`.

- [ ] **Step 5: Implement `WaveDirector.swift`**. Internal state: `waveClock: Double` (time since wave became eligible), `waveStarted: Bool`, per-group `issued: Int` and `nextSpawnAt: Double`. A wave is *eligible* when the previous wave has issued all spawns and `aliveMobs == 0` (for index 0: at level start). Accumulate `dt` into the clock only while eligible; when `clock >= delay` start the wave and issue each group's first spawn; thereafter issue spawns as `clock - startTime` passes `issued * interval`. Multiple spawns from one group may be issued in a single tick if `dt` spans several intervals.

- [ ] **Step 6: Run to verify pass** — `swift test 2>&1 | tail -2`. Expected: `Executed 15 tests, with 0 failures`.

- [ ] **Step 7: Commit** — `git commit -am "feat(core): level JSON definition and wave director"` (after `git add -A`).

---

### Task 4: World combat simulation

**Files:**
- Create: `HiveCore/Sources/HiveCore/Entities/Hive.swift`, `HiveCore/Sources/HiveCore/Entities/Projectile.swift`, `HiveCore/Sources/HiveCore/World/GameEvent.swift`, `HiveCore/Sources/HiveCore/World/RunPhase.swift`, `HiveCore/Sources/HiveCore/World/World.swift`
- Test: `HiveCore/Tests/HiveCoreTests/WorldCombatTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct HiveStats: Equatable {
      public var maxHP: Double = 100, damage: Double = 10, fireRate: Double = 2 /* shots per second */
      public var projectileCount: Int = 1, pierce: Int = 0 /* extra mobs a stinger passes through */
      public var projectileSpeed: Double = 420
      public static let base = HiveStats()
  }
  public struct Hive: Equatable { public var stats: HiveStats; public var hp: Double; public var cooldown: Double; public static let radius: Double = 40 }

  public struct Projectile: Identifiable, Equatable { public let id: Int; public var position: Vec2; public var velocity: Vec2; public let damage: Double; public var pierceRemaining: Int; public var hitMobIDs: [Int]; public static let radius: Double = 4; public static let maxRange: Double = 700 }

  public enum GameEvent: Equatable {
      case mobSpawned(id: Int, type: MobType)
      case projectileFired(id: Int)
      case mobHit(id: Int)
      case mobKilled(id: Int, type: MobType, at: Vec2)
      case hiveDamaged(amount: Double, hp: Double)
      case waveStarted(number: Int, isBoss: Bool)
      case nectarThreshold          // Task 5 fills in the card draw
      case levelCleared
      case gameOver
  }
  public enum RunPhase: Equatable { case playing, pickingCards([UpgradeCard]) /* Task 5 */, cleared, gameOver }

  public struct World {
      public init(level: LevelDefinition, hiveStats: HiveStats = .base, seed: UInt64)
      public private(set) var hive: Hive
      public private(set) var mobs: [Mob]
      public private(set) var projectiles: [Projectile]
      public private(set) var director: WaveDirector
      public private(set) var phase: RunPhase
      public private(set) var time: Double
      public var nectar: NectarMeter          // Task 5; stub as empty struct in this task
      public static let spawnRadius: Double = 520
      @discardableResult public mutating func tick(dt: Double) -> [GameEvent]
  }
  ```
  For this task, `UpgradeCard` and `NectarMeter` are declared as empty placeholder types in `World.swift` (`public struct UpgradeCard: Equatable {}`, `public struct NectarMeter: Equatable {}`), to be replaced by Task 5 (move to their own files then).
- Tick order inside `tick(dt:)` when `phase == .playing`: (1) `dt <= 0` → return `[]`. (2) `time += dt`. (3) director tick → spawn mobs at a random angle on `spawnRadius` (emit `waveStarted` when `director.waveNumber` changes). (4) move mobs toward origin by `speed*dt`. (5) move projectiles; remove any beyond `maxRange` from origin. (6) projectile–mob collisions: distance `< Mob.radius + Projectile.radius`, skip ids already in `hitMobIDs`; apply damage, emit `mobHit`, set `hitFlash = 0.08`; if `hp <= 0` emit `mobKilled` and mark dead; decrement `pierceRemaining`, remove projectile when `< 0`. (7) remove dead mobs. (8) mob–hive contact: distance `< Hive.radius + mob.radius` → `hive.hp -= contactDamage`, emit `hiveDamaged`, remove mob. (9) if `hive.hp <= 0` → `phase = .gameOver`, emit `gameOver`, return. (10) hive fire: `cooldown -= dt`; while `cooldown <= 0` and a target exists: fire `projectileCount` projectiles at the nearest mob with a spread of 10° between projectiles centered on the target; `cooldown += 1/fireRate`; if no target, clamp `cooldown` to `max(cooldown, 0)`. (11) decay `hitFlash`. (12) if `director.allSpawnsIssued && mobs.isEmpty` → `phase = .cleared`, emit `levelCleared`.

- [ ] **Step 1: Write the failing tests**

```swift
// WorldCombatTests.swift
final class WorldCombatTests: XCTestCase {
    /// one wave, one wasp, no delay
    func oneWaspLevel() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":1,"name":"t","waves":[{"delay":0,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#.utf8)) }
    func oneBearBossLevel() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":2,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"bear","count":1,"interval":0}]}]}"#.utf8)) }
    func run(_ w: inout World, seconds: Double) -> [GameEvent] { var ev: [GameEvent] = []; var t = 0.0; while t < seconds { ev += w.tick(dt: 1.0/60); t += 1.0/60 }; return ev }

    func testTickWithZeroDtChangesNothing() {
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = w.tick(dt: 1.0/60)
        let before = (w.mobs, w.projectiles, w.hive, w.time)
        XCTAssertEqual(w.tick(dt: 0), [])
        XCTAssertEqual(w.mobs, before.0); XCTAssertEqual(w.projectiles, before.1); XCTAssertEqual(w.hive, before.2); XCTAssertEqual(w.time, before.3)
    }
    func testWaspSpawnsOnSpawnRadius() {
        var w = World(level: oneWaspLevel(), seed: 1)
        let ev = w.tick(dt: 1.0/60)
        XCTAssertTrue(ev.contains(.mobSpawned(id: w.mobs[0].id, type: .wasp)))
        XCTAssertTrue(ev.contains(.waveStarted(number: 1, isBoss: false)))
        XCTAssertEqual(w.mobs[0].position.length, World.spawnRadius, accuracy: 1e-6)
    }
    func testHiveFiresAtNearestMobAtFireRate() {
        var w = World(level: oneWaspLevel(), seed: 1)
        let ev = run(&w, seconds: 0.9)
        let shots = ev.filter { if case .projectileFired = $0 { return true }; return false }.count
        XCTAssertEqual(shots, 2)   // fireRate 2/s: shots at t≈0 and t≈0.5; 0.9 s avoids the boundary at 1.0
    }
    func testWaspDiesBeforeReachingHiveAndLevelClears() {
        var w = World(level: oneWaspLevel(), seed: 1)
        let ev = run(&w, seconds: 8.0)
        XCTAssertTrue(ev.contains { if case .mobKilled(_, .wasp, _) = $0 { return true }; return false })
        XCTAssertFalse(ev.contains { if case .hiveDamaged = $0 { return true }; return false })
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(ev.filter { $0 == .levelCleared }.count, 1)
        XCTAssertTrue(w.mobs.isEmpty)
    }
    func testKilledMobDoesNotDealContactDamage() {
        // hive does 10 dmg per shot; wasp has 20 hp; put a wasp at the hive edge with 10 hp and a projectile on top of it
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = w.tick(dt: 1.0/60)
        w.debugSetMob(index: 0, position: Vec2(Hive.radius + 10 + 0.5, 0), hp: 10)
        w.debugAddProjectile(at: Vec2(Hive.radius + 10 + 0.5, 0), velocity: .zero, damage: 10)
        let ev = w.tick(dt: 1.0/60)
        XCTAssertTrue(ev.contains { if case .mobKilled = $0 { return true }; return false })
        XCTAssertFalse(ev.contains { if case .hiveDamaged = $0 { return true }; return false })
        XCTAssertEqual(w.hive.hp, 100)
    }
    func testContactDamageAndGameOver() {
        var w = World(level: oneBearBossLevel(), hiveStats: HiveStats(maxHP: 30, damage: 0.0001, fireRate: 0.01), seed: 3)
        let ev = run(&w, seconds: 30)
        XCTAssertTrue(ev.contains(.hiveDamaged(amount: 40, hp: -10)))
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(ev.filter { $0 == .gameOver }.count, 1)
        XCTAssertFalse(ev.contains(.levelCleared))
    }
    func testBossWaveClearedByContactStillResolvesOnce() {
        // hive survives the bear's contact (hp 100 vs 40) and the bear dies on contact → cleared exactly once, no gameOver
        var w = World(level: oneBearBossLevel(), hiveStats: HiveStats(damage: 0.0001, fireRate: 0.01), seed: 3)
        let ev = run(&w, seconds: 30)
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(ev.filter { $0 == .levelCleared }.count, 1)
        XCTAssertFalse(ev.contains(.gameOver))
    }
    func testPierceHitsSecondMobOnce() {
        var w = World(level: oneWaspLevel(), hiveStats: HiveStats(pierce: 1), seed: 1)
        _ = w.tick(dt: 1.0/60)
        w.debugSetMob(index: 0, position: Vec2(200, 0), hp: 20)
        w.debugAddMob(type: .wasp, position: Vec2(230, 0))
        w.debugAddProjectile(at: Vec2(190, 0), velocity: Vec2(600, 0), damage: 5)
        let ev = run(&w, seconds: 0.2)
        XCTAssertEqual(ev.filter { if case .mobHit = $0 { return true }; return false }.count, 2)
    }
    func testTicksAfterTerminalPhaseAreNoOps() {
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = run(&w, seconds: 8)
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(w.tick(dt: 1.0/60), [])
    }
}
```
Add to `World` (internal, `#if DEBUG`-free so tests can call via `@testable`): `mutating func debugSetMob(index: Int, position: Vec2, hp: Double)`, `mutating func debugAddMob(type: MobType, position: Vec2)`, `mutating func debugAddProjectile(at: Vec2, velocity: Vec2, damage: Double)`.

- [ ] **Step 2: Run to verify fail** — `swift test 2>&1 | grep -E "error:" | head -3`.

- [ ] **Step 3: Implement `Hive.swift`, `Projectile.swift`, `GameEvent.swift`, `RunPhase.swift`, `World.swift`** per the interfaces and the tick order above. Hornet, bear, and the pierce test rely on `hitMobIDs` so one projectile never hits the same mob twice. Spawn angle: `rng.unitDouble() * 2π`. `HiveStats` gets a memberwise `public init` with all defaults so tests can call `HiveStats(pierce: 1)`.

- [ ] **Step 4: Run to verify pass** — `swift test 2>&1 | tail -2`. Expected: `Executed 24 tests, with 0 failures`.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): world simulation with targeting, projectiles, contact damage, phases"`

---

### Task 5: Nectar meter, upgrade cards, card pick

**Files:**
- Create: `HiveCore/Sources/HiveCore/Upgrades/UpgradeCard.swift`, `HiveCore/Sources/HiveCore/Upgrades/UpgradeCatalog.swift`, `HiveCore/Sources/HiveCore/Upgrades/NectarMeter.swift`
- Modify: `HiveCore/Sources/HiveCore/World/World.swift` (remove placeholders, add nectar + pick flow)
- Test: `HiveCore/Tests/HiveCoreTests/NectarAndCardsTests.swift`, `HiveCore/Tests/HiveCoreTests/RunPhaseTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum CardRarity: String, Codable { case common, rare, epic }
  public enum CardEffect: Equatable { case fireRateMultiplier(Double), damageMultiplier(Double), addProjectile(Int), addPierce(Int), addMaxHP(Double, healBy: Double), healFraction(Double) }
  public struct UpgradeCard: Identifiable, Equatable { public let id: String; public let name: String; public let description: String; public let rarity: CardRarity; public let effect: CardEffect }

  public enum UpgradeCatalog {
      public static let milestone1: [UpgradeCard]   // the 6 below
      /// Draws `count` distinct cards weighted by rarity: common 70, rare 25, epic 5.
      public static func draw(count: Int, from pool: [UpgradeCard], rng: inout SeededRNG) -> [UpgradeCard]
  }
  public struct NectarMeter: Equatable {
      public init()
      public private(set) var level: Int        // thresholds crossed so far, starts 0
      public private(set) var current: Int
      public var threshold: Int                 // for current level: [8, 16, 28, 44, 64, 90][level] else 90 + 30*(level-5)
      /// Adds nectar; returns true if a threshold was crossed (at most one per call; excess carries over).
      public mutating func add(_ amount: Int) -> Bool
  }
  extension HiveStats { public mutating func apply(_ effect: CardEffect, to hive: inout Hive) }   // see rules
  extension World { public mutating func choose(_ card: UpgradeCard) }   // only valid in .pickingCards; applies, phase → .playing
  ```
- The six cards (id, name, description, rarity, effect):
  1. `rapid_stingers`, "Rapid Stingers", "+25% fire rate", common, `.fireRateMultiplier(1.25)`
  2. `venom`, "Venom", "+30% damage", common, `.damageMultiplier(1.30)`
  3. `twin_stinger`, "Twin Stinger", "+1 projectile", rare, `.addProjectile(1)`
  4. `piercing`, "Piercing Stinger", "Stingers pass through 1 more mob", rare, `.addPierce(1)`
  5. `propolis_armor`, "Propolis Armor", "+30 max HP, heal 30", common, `.addMaxHP(30, healBy: 30)`
  6. `royal_jelly`, "Royal Jelly", "Heal 50% of max HP", common, `.healFraction(0.5)`
- Apply rules: multipliers multiply the stat; `addMaxHP` raises `stats.maxHP` and `hive.hp` by the amounts, hp clamped to maxHP; `healFraction` adds `fraction*maxHP` clamped to maxHP.
- World changes: on `mobKilled`, `nectar.add(type.stats.nectar)`; if it returns true and `phase == .playing`, set `phase = .pickingCards(UpgradeCatalog.draw(count: 3, from: .milestone1, rng: &rng))` and emit `.nectarThreshold`, then **stop processing the tick** (return events so far). `tick` while `.pickingCards` returns `[]`.

- [ ] **Step 1: Write the failing tests**

```swift
// NectarAndCardsTests.swift
final class NectarAndCardsTests: XCTestCase {
    func testThresholdsAndCarryOver() {
        var m = NectarMeter()
        XCTAssertEqual(m.threshold, 8)
        XCTAssertFalse(m.add(7))
        XCTAssertTrue(m.add(3))                 // 10 ≥ 8 → crossed, carry 2
        XCTAssertEqual(m.level, 1); XCTAssertEqual(m.current, 2); XCTAssertEqual(m.threshold, 16)
    }
    func testOnlyOneThresholdPerAdd() {
        var m = NectarMeter()
        XCTAssertTrue(m.add(100))               // crosses 8, carries 92 ≥ 16 but level advances once
        XCTAssertEqual(m.level, 1); XCTAssertEqual(m.current, 92)
        XCTAssertTrue(m.add(0))                 // next add resolves the pending threshold
        XCTAssertEqual(m.level, 2); XCTAssertEqual(m.current, 76)
    }
    func testLateThresholdFormula() {
        var m = NectarMeter()
        for _ in 0..<6 { _ = m.add(1000); }      // level 6 (each add crosses one)
        XCTAssertEqual(m.level, 6); XCTAssertEqual(m.threshold, 120)
    }
    func testDrawReturnsDistinctCards() {
        var rng = SeededRNG(seed: 5)
        for _ in 0..<50 {
            let cards = UpgradeCatalog.draw(count: 3, from: UpgradeCatalog.milestone1, rng: &rng)
            XCTAssertEqual(cards.count, 3); XCTAssertEqual(Set(cards.map(\.id)).count, 3)
        }
    }
    func testDrawIsDeterministicForSeed() {
        var a = SeededRNG(seed: 9), b = SeededRNG(seed: 9)
        XCTAssertEqual(UpgradeCatalog.draw(count: 3, from: UpgradeCatalog.milestone1, rng: &a).map(\.id),
                       UpgradeCatalog.draw(count: 3, from: UpgradeCatalog.milestone1, rng: &b).map(\.id))
    }
    func testRarityWeighting() {
        var rng = SeededRNG(seed: 11); var rare = 0
        for _ in 0..<2000 { if UpgradeCatalog.draw(count: 1, from: UpgradeCatalog.milestone1, rng: &rng)[0].rarity == .rare { rare += 1 } }
        // 2 rare cards weight 25 each vs 4 common weight 70 each → rare share 50/330 ≈ 15%
        XCTAssert(rare > 220 && rare < 400, "rare drawn \(rare) times")
    }
    func testApplyEffects() {
        var stats = HiveStats.base; var hive = Hive(stats: stats, hp: 60, cooldown: 0)
        stats.apply(.fireRateMultiplier(1.25), to: &hive); XCTAssertEqual(stats.fireRate, 2.5)
        stats.apply(.damageMultiplier(1.3), to: &hive); XCTAssertEqual(stats.damage, 13, accuracy: 1e-9)
        stats.apply(.addProjectile(1), to: &hive); XCTAssertEqual(stats.projectileCount, 2)
        stats.apply(.addPierce(1), to: &hive); XCTAssertEqual(stats.pierce, 1)
        stats.apply(.addMaxHP(30, healBy: 30), to: &hive); XCTAssertEqual(stats.maxHP, 130); XCTAssertEqual(hive.hp, 90)
        stats.apply(.healFraction(0.5), to: &hive); XCTAssertEqual(hive.hp, 130)   // 90+65 clamped
    }
}
// RunPhaseTests.swift
final class RunPhaseTests: XCTestCase {
    /// 10 wasps at once, no delay: 10 nectar crosses the first threshold (8)
    func tenWasps() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":3,"name":"t","waves":[{"delay":0,"spawns":[{"type":"wasp","count":10,"interval":0}]}]}"#.utf8)) }
    func runUntilPicking(_ w: inout World, max: Double = 30) -> [GameEvent] {
        var ev: [GameEvent] = []; var t = 0.0
        while t < max { ev += w.tick(dt: 1.0/60); t += 1.0/60; if case .pickingCards = w.phase { break } }
        return ev
    }
    func testNectarThresholdPausesIntoCardPick() {
        var w = World(level: tenWasps(), hiveStats: HiveStats(damage: 20, fireRate: 10, projectileCount: 3), seed: 2)
        let ev = runUntilPicking(&w)
        guard case .pickingCards(let cards) = w.phase else { return XCTFail("expected pickingCards, got \(w.phase)") }
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(ev.filter { $0 == .nectarThreshold }.count, 1)
    }
    func testTickWhilePickingIsNoOp() {
        var w = World(level: tenWasps(), hiveStats: HiveStats(damage: 20, fireRate: 10, projectileCount: 3), seed: 2)
        _ = runUntilPicking(&w)
        let snapshot = (w.mobs, w.hive, w.time)
        XCTAssertEqual(w.tick(dt: 1.0/60), [])
        XCTAssertEqual(w.mobs, snapshot.0); XCTAssertEqual(w.hive, snapshot.1); XCTAssertEqual(w.time, snapshot.2)
    }
    func testChooseAppliesCardAndResumes() {
        var w = World(level: tenWasps(), hiveStats: HiveStats(damage: 20, fireRate: 10, projectileCount: 3), seed: 2)
        _ = runUntilPicking(&w)
        let venom = UpgradeCatalog.milestone1.first { $0.id == "venom" }!
        w.choose(venom)
        XCTAssertEqual(w.phase, .playing)
        XCTAssertEqual(w.hive.stats.damage, 26, accuracy: 1e-9)
        let timeBefore = w.time
        _ = w.tick(dt: 1.0/60)
        XCTAssertGreaterThan(w.time, timeBefore)   // world advances again
    }
    func testNectarCarriesOverAfterThreshold() {
        var w = World(level: tenWasps(), hiveStats: HiveStats(damage: 20, fireRate: 10, projectileCount: 3), seed: 2)
        _ = runUntilPicking(&w)
        XCTAssertEqual(w.nectar.level, 1)
        XCTAssertGreaterThanOrEqual(w.nectar.current, 0)
        XCTAssertLessThan(w.nectar.current, w.nectar.threshold)
    }
}
```
- [ ] **Step 2: Run to verify fail** — expected unresolved `NectarMeter.init`, `UpgradeCatalog`, `choose`.

- [ ] **Step 3: Implement `UpgradeCard.swift`, `UpgradeCatalog.swift`, `NectarMeter.swift`** per interfaces. Draw algorithm: weighted sampling without replacement (pick one by cumulative weight using `rng.unitDouble()`, remove it, repeat). Remove the placeholder types from `World.swift`, add `nectar`, the threshold → `pickingCards` transition, `choose(_:)`, and the `.pickingCards` early return.

- [ ] **Step 4: Run to verify pass** — `swift test 2>&1 | tail -2`. Expected: `Executed 35 tests, with 0 failures`.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): nectar meter, upgrade cards, card pick flow"`

---

### Task 6: Render the world (hive, mobs, projectiles)

**Files:**
- Create: `Hive/Rendering/HiveNode.swift`, `Hive/Rendering/MobNode.swift`, `Hive/Rendering/ProjectileNode.swift`, `Hive/Resources/Levels/level_001.json`
- Modify: `Hive/Scenes/GameScene.swift`, `project.yml` (add `Hive/Resources/Levels` as a folder resource if XcodeGen does not pick it up from `sources: [Hive]`; verify `Hive.app/Levels/level_001.json` exists in the built product)

**Interfaces:**
- Consumes: `World`, `LevelDefinition.load`, `Mob`, `Projectile`, `Palette`.
- Produces:
  - `final class HiveNode: SKNode { init(tier: Int) }` — tier 1 only in this milestone: a center hexagon (circumradius 16) plus a ring of 6 hexagons (circumradius 14) at distance 28, all `SKShapeNode` with `fillColor = Palette.amber` (center `Palette.gold`), `strokeColor = Palette.burntOrange`, `lineWidth = 1.5`, `glowWidth = 6`. Behind them one `SKShapeNode(circleOfRadius: 48)` filled `Palette.amber` alpha 0.12 with `glowWidth = 18` as ambient glow. Pulses: ambient glow `SKAction.repeatForever(sequence(scale 1.0→1.06 over 1.4s, back))`. Hexagons drawn with a `CGPath` helper `hexPath(circumradius:)`, flat-top orientation.
  - `final class MobNode: SKNode { init(type: MobType); func setHitFlash(_ on: Bool) }` — wasp: `SKShapeNode` diamond (rhombus, width 20, height 12) filled `Palette.slate`; hornet: hexagon circumradius 14 filled `Palette.violet`; bear: rounded-rect 60×50 (corner 14) filled `Palette.sicklyGreen` with a thin `Palette.white` alpha 0.25 stroke. All `lineWidth = 1`, no faces. `setHitFlash(true)` sets `fillColor = Palette.white`; `false` restores the type color. Mob nodes rotate to face the origin (`zRotation = atan2(-y, -x)`).
  - `final class ProjectileNode: SKShapeNode` — circle radius 4, fill white, `glowWidth = 4`, alpha 0.95.
  - `GameScene`: properties `world: World`, `mobNodes: [Int: MobNode]`, `projectileNodes: [Int: ProjectileNode]`, `lastUpdate: TimeInterval?`. `didMove(to:)` loads `Levels/level_001.json` from `Bundle.main` via `LevelDefinition.load`, `fatalError("Failed to load level_001.json: \(error)")` on failure, creates `World(level:, seed: UInt64(Date().timeIntervalSince1970))`, adds `HiveNode(tier: 1)` at origin. `update(_:)` computes `dt = min(currentTime - last, 1.0/30)` (first frame: `dt = 0`), calls `world.tick(dt:)`, then `reconcile()`: for each `world.mobs` create/update node position and hit flash (`hitFlash > 0`), remove nodes whose id is absent; same for projectiles. Events are ignored in this task except logging `levelCleared`/`gameOver` with `print`.

- [ ] **Step 1: Write `Hive/Resources/Levels/level_001.json`**

```json
{ "id": 1, "name": "First Light", "waves": [
  { "delay": 1.5, "spawns": [ { "type": "wasp", "count": 6,  "interval": 0.9 } ] },
  { "delay": 2.5, "spawns": [ { "type": "wasp", "count": 10, "interval": 0.6 } ] },
  { "delay": 2.5, "spawns": [ { "type": "wasp", "count": 8,  "interval": 0.5 }, { "type": "hornet", "count": 3, "interval": 2.5 } ] },
  { "delay": 2.5, "spawns": [ { "type": "hornet", "count": 5, "interval": 1.6 }, { "type": "wasp", "count": 10, "interval": 0.4 } ] },
  { "delay": 3.0, "isBoss": true, "spawns": [ { "type": "bear", "count": 1, "interval": 0 }, { "type": "wasp", "count": 14, "interval": 0.5 }, { "type": "hornet", "count": 4, "interval": 2.0 } ] }
] }
```

- [ ] **Step 2: Implement `HiveNode`, `MobNode`, `ProjectileNode`, and the `GameScene` changes** per the interfaces above.

- [ ] **Step 3: Build** — the Task 1 build command. Expected: `** BUILD SUCCEEDED **`, and `ls build/Build/Products/Debug-iphonesimulator/Hive.app/Levels/level_001.json` exists. If it does not, add to `project.yml` under the target: `sources: [Hive, {path: Hive/Resources/Levels, type: folder, buildPhase: resources}]` and rebuild.

- [ ] **Step 4: Run in the simulator and verify** — launch, wait 6 s, screenshot. Expected: amber hex cluster glowing at center; slate diamonds moving inward from off-screen; white dots flying outward and mobs flashing white and vanishing. Wait 60 s more, screenshot: violet hexagons and eventually a green rounded block (bear). Console shows either `levelCleared` or `gameOver` within ~2 minutes; the game then freezes on the last frame (expected; overlays are Task 7).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(app): render hive, mobs, projectiles from World; level 1 script"`

---

### Task 7: HUD, card pick overlay, end overlay, retry

**Files:**
- Create: `Hive/Rendering/HUDNode.swift`, `Hive/Rendering/CardPickOverlay.swift`, `Hive/Rendering/EndOverlay.swift`
- Modify: `Hive/Scenes/GameScene.swift`

**Interfaces:**
- Consumes: `World.phase`, `World.hive`, `World.nectar`, `World.director.waveNumber/totalWaves/isBossWave`, `World.choose(_:)`, `UpgradeCard`.
- Produces:
  - `final class HUDNode: SKNode { init(viewSize: CGSize); func update(hp: Double, maxHP: Double, wave: Int, totalWaves: Int, isBoss: Bool, nectar: Int, nectarThreshold: Int) }` — top: HP bar 220×8 pt centered 60 pt below the top edge, track `Palette.burntOrange` alpha 0.3, fill `Palette.gold` → turns `Palette.white` under 25%; wave label `SKLabelNode(fontNamed: "SFProRounded-Semibold")` 15 pt `Palette.gold` alpha 0.85 reading `WAVE 3 / 5` or `BOSS` ; bottom: nectar bar full-width minus 32 pt margins, 6 pt tall, 48 pt above the bottom edge, fill `Palette.amber`. The HUD is a child of a `cameraNode`-free scene, so positions are computed from `viewSize` with the scene's centered anchor.
  - `final class CardPickOverlay: SKNode { init(cards: [UpgradeCard], viewSize: CGSize, onPick: @escaping (UpgradeCard) -> Void) }` — dim layer `SKSpriteNode(color: black alpha 0.72, size: viewSize)`, title "CHOOSE AN UPGRADE" 14 pt gold tracking, three cards stacked vertically 300×84 pt with 14 pt gaps, each a rounded rect (corner 14) fill `#15120C`, stroke `Palette.amber` alpha 0.6 (rare: `Palette.gold` alpha 0.9, `lineWidth 2`), name 18 pt white, description 13 pt gold alpha 0.8, rarity tag 10 pt uppercase at top-right. Tap detection via `nodes(at:)` and a `name` of `card:<id>`. `onPick` is called once; the overlay removes itself.
  - `final class EndOverlay: SKNode { init(cleared: Bool, wave: Int, viewSize: CGSize, onRetry: @escaping () -> Void) }` — dim layer; title "HIVE SURVIVED" (gold) or "HIVE FELL" (white alpha 0.9) 30 pt; subtitle `Reached wave N` 14 pt; one button 220×52 pt rounded rect, fill `Palette.amber`, label "RETRY" 16 pt `#0B0A08`, node name `retry`.
  - `GameScene` additions: `hud: HUDNode`, `overlay: SKNode?`, `func startRun()` (removes all mob/projectile nodes, builds a fresh `World` with a new seed, clears `overlay`), `touchesBegan` routes to the overlay when present (ignores touches otherwise), and after each `tick`: when `phase` becomes `.pickingCards(cards)` and `overlay == nil` present `CardPickOverlay` whose `onPick` calls `world.choose(card)`; when `.cleared` / `.gameOver` present `EndOverlay` whose `onRetry` calls `startRun()`. HUD updates every frame. Overlays and HUD have `zPosition` 100/200; game nodes 0–10.

- [ ] **Step 1: Implement the three nodes and the scene changes** per the interfaces.

- [ ] **Step 2: Build** — Task 1 build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify in the simulator** — launch; screenshot at ~3 s: HP bar full, `WAVE 1 / 5`, empty nectar bar. Let it run until the card overlay appears (first threshold is 8 nectar, roughly 8 wasp kills, within ~15 s); screenshot: three cards readable, game frozen behind dim. Tap the first card (coordinates from the screenshot); screenshot: overlay gone, play resumed. Let the run end; screenshot the end overlay; tap RETRY; screenshot: fresh run, `WAVE 1 / 5`, HP full.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(app): HUD, upgrade card overlay, end-of-run overlay with retry"`

---

### Task 8: Difficulty pass and milestone verification

**Files:**
- Modify: `Hive/Resources/Levels/level_001.json` (numbers only), possibly `HiveStats.base` defaults in `HiveCore/Sources/HiveCore/Entities/Hive.swift` if level 1 is unwinnable with good cards.
- Create: `README.md`

**Interfaces:** none new.

- [ ] **Step 1: Add a headless balance probe test** in `HiveCore/Tests/HiveCoreTests/BalanceProbeTests.swift`: loads `Hive/Resources/Levels/level_001.json` via a relative path from `#filePath` (`../../../../Hive/Resources/Levels/level_001.json`), runs the world at 60 Hz for up to 300 s with an **always-pick-first-card** policy, for seeds 1…20, and asserts (a) no seed clears the level with base stats and the first-card policy on the first threshold only (i.e. `cleared` count across 20 seeds is `≤ 6`), and (b) at least 1 seed survives past the boss wave starting. Print `cleared X / 20, avg survival wave Y`. This encodes spec 5.3 ("a fresh player should lose") loosely for level 1: hard, not impossible.

- [ ] **Step 2: Run** — `swift test --filter BalanceProbeTests 2>&1 | tail -5`. If `cleared > 6`, raise wasp/hornet counts in waves 3–5 by 20% and rerun; if `cleared == 0` and no seed reaches the boss, lower wave 4–5 counts by 15%. Record final numbers in the test's print output.

- [ ] **Step 3: Play two full runs on the simulator**, choosing cards deliberately. Expected: at least one of the two runs ends in `HIVE FELL` at wave 4 or 5; a run with Twin Stinger + Venom early should reach the bear. Screenshot the end screens.

- [ ] **Step 4: Rename the level file temporarily** (`mv level_001.json level_001.json.bak`, rebuild, launch): the app must crash immediately with `Failed to load level_001.json` in the simulator log. Restore the file, rebuild, confirm it runs.

- [ ] **Step 5: Write `README.md`**: one paragraph on the game, the two commands (`cd HiveCore && swift test`; the xcodebuild line), how to launch on the simulator, where level JSON lives and the fields it accepts, and a pointer to the spec and this plan.

- [ ] **Step 6: Full test run and commit** — `cd HiveCore && swift test 2>&1 | tail -2` → `0 failures`. `git add -A && git commit -m "feat: tune level 1 difficulty, balance probe, README (milestone 1 playable core)"`.

---

## Self-review notes

- **Spec coverage (milestone 1 only):** hive auto-fire ✔ (T4), one+ mob types ✔ (T2, spec milestone says "one", plan ships three so level 1 has a boss), HP ✔, nectar bar ✔ (T5, T7), three-card pick with ~6 cards ✔ (T5, T7), one hand-written level ✔ (T6), game over/retry ✔ (T7), visible in simulator ✔ (T1, T6–T8), visual direction 5.5 ✔ (Palette, HiveNode, MobNode), difficulty philosophy 5.3 ✔ (T8 probe). Not in this milestone by design: coins, home/upgrades screens, save, endless, ads, sound, particles.
- **Type consistency:** `HiveStats` fields used in T4 tests match the T4 interface (`maxHP, damage, fireRate, projectileCount, pierce`); `NectarMeter.level/current/threshold/add` used in T5 tests and T7 HUD; `World.choose(_:)` named consistently; `director.waveNumber/totalWaves/isBossWave` used by T7 are declared in T3.
- **Review Focus** items each have a named test in T3/T4/T5 and a manual check in T8.
- **Proportion:** plan ≈ 2.5× spec length; code blocks are tests and data, no production bodies beyond the tick order list, which is an algorithm the signatures do not determine.
