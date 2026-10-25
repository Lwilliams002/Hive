import XCTest
import Foundation
@testable import HiveCore

/// The downed phase and `revive()` / `abandonRevive()` (M4 rulings R1–R5). The fixture is the
/// `WorldCombatTests:51` trajectory with `reviveAllowed: true`: the bear parks at length 70 at 16.1 s and its
/// 40-point hit takes the 30-HP hive to −10, leaving its `attackCooldown` at 1 − 1/60 ≈ 0.9833.
final class ReviveTests: XCTestCase {
    func oneBearBossLevel() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":2,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"bear","count":1,"interval":0}]}]}"#.utf8)) }
    func run(_ w: inout World, seconds: Double) -> [GameEvent] { var ev: [GameEvent] = []; var t = 0.0; while t < seconds { ev += w.tick(dt: 1.0/60); t += 1.0/60 }; return ev }

    let weakHive = HiveStats(maxHP: 30, damage: 0.0001, fireRate: 0.01)

    /// A revive-armed weak hive run 30 s against one bear: downed at 16.1 s with hp −10.
    func downedWorld(_ events: inout [GameEvent]) -> World {
        var w = World(level: oneBearBossLevel(), hiveStats: weakHive, seed: 3, reviveAllowed: true)
        events += run(&w, seconds: 30)
        return w
    }
    func downedWorld() -> World { var ev: [GameEvent] = []; return downedWorld(&ev) }

    func count(_ ev: [GameEvent], _ e: GameEvent) -> Int { ev.filter { $0 == e }.count }

    func testDownedOnlyWhenReviveAllowed() {
        // Default init: exactly today's trajectory (re-pins WorldCombatTests:51).
        var plain = World(level: oneBearBossLevel(), hiveStats: weakHive, seed: 3)
        let ev = run(&plain, seconds: 30)
        XCTAssertEqual(plain.phase, .gameOver)
        XCTAssertEqual(count(ev, .gameOver), 1)
        XCTAssertEqual(count(ev, .hiveDowned), 0)
        XCTAssertEqual(plain.hive.hp, -10)

        var downedEvents: [GameEvent] = []
        let w = downedWorld(&downedEvents)
        XCTAssertEqual(w.phase, .downed)
        XCTAssertEqual(count(downedEvents, .hiveDowned), 1)
        XCTAssertEqual(count(downedEvents, .gameOver), 0)
        XCTAssertEqual(w.hive.hp, -10)
        XCTAssertFalse(w.reviveUsed)
    }

    func testReviveRestoresHalfHPAndKeepsRunID() {
        var w = downedWorld()
        let id = w.runID, nectarBefore = w.nectar, timeBefore = w.time, projBefore = w.projectiles
        XCTAssertEqual(w.revive(), [])
        XCTAssertEqual(w.hive.hp, 15)
        XCTAssertEqual(w.phase, .playing)
        XCTAssertTrue(w.reviveUsed)
        XCTAssertEqual(w.runID, id)
        XCTAssertEqual(w.nectar, nectarBefore)
        XCTAssertEqual(w.time, timeBefore)
        XCTAssertEqual(w.projectiles, projBefore)
        XCTAssertEqual(w.mobs.count, 1)
        XCTAssertEqual(w.mobs[0].position.length, 70, accuracy: 1e-6)   // the boss is never displaced
        _ = w.tick(dt: 1.0/60)
        XCTAssertGreaterThan(w.time, timeBefore)
    }

    func testReviveDelaysParkedBoss() {
        var w = downedWorld()
        XCTAssertLessThan(w.mobs[0].attackCooldown, 1.5)
        _ = w.revive()
        XCTAssertEqual(w.mobs[0].attackCooldown, 1.5, accuracy: 1e-9)
        let quiet = run(&w, seconds: 1.3)
        XCTAssertFalse(quiet.contains { if case .hiveDamaged = $0 { return true }; return false })
        XCTAssertEqual(w.hive.hp, 15)
        let fall = run(&w, seconds: 0.4)
        XCTAssertTrue(fall.contains(.hiveDamaged(amount: 40, hp: -25)))
        XCTAssertEqual(count(fall, .gameOver), 1)
        XCTAssertEqual(count(fall, .hiveDowned), 0)   // a revived hive that dies again skips `.downed` (R2)
        XCTAssertEqual(w.phase, .gameOver)
    }

    func testReviveClearsNearbyNonBossMobs() {
        var w = downedWorld()
        w.debugAddMob(type: .wasp, position: Vec2(60, 0))
        w.debugAddMob(type: .hornet, position: Vec2(0, -100))
        w.debugAddMob(type: .wasp, position: Vec2(200, 0))
        w.debugAddMob(type: .beetle, position: Vec2(0, 0))
        let nectarBefore = w.nectar.current
        XCTAssertEqual(w.revive(), [])   // displaced, never killed
        XCTAssertEqual(w.mobs.count, 5)
        XCTAssertEqual(w.mobs[0].position.length, 70, accuracy: 1e-6)   // the bear stays parked
        XCTAssertEqual(w.mobs[1].position.x, 160, accuracy: 1e-9); XCTAssertEqual(w.mobs[1].position.y, 0, accuracy: 1e-9)
        XCTAssertEqual(w.mobs[2].position.x, 0, accuracy: 1e-9); XCTAssertEqual(w.mobs[2].position.y, -164, accuracy: 1e-9)
        XCTAssertEqual(w.mobs[3].position.x, 200, accuracy: 1e-9); XCTAssertEqual(w.mobs[3].position.y, 0, accuracy: 1e-9)
        XCTAssertEqual(w.mobs[4].position.x, 163, accuracy: 1e-9); XCTAssertEqual(w.mobs[4].position.y, 0, accuracy: 1e-9)
        XCTAssertEqual(w.nectar.current, nectarBefore)
    }

    func testReviveRefusedTwice() {
        var w = downedWorld()
        _ = w.revive()
        var t = 0.0
        while t < 3 && w.phase != .gameOver { _ = w.tick(dt: 1.0/60); t += 1.0/60 }
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(w.revive(), [])
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(w.hive.hp, -25)

        var fresh = World(level: oneBearBossLevel(), hiveStats: weakHive, seed: 3, reviveAllowed: true)
        XCTAssertEqual(fresh.phase, .playing)
        XCTAssertEqual(fresh.revive(), [])
        XCTAssertEqual(fresh.hive.hp, 30)
    }

    func testAbandonReviveEntersGameOverOnce() {
        var w = downedWorld()
        XCTAssertEqual(w.abandonRevive(), [.gameOver])
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(w.abandonRevive(), [])
        XCTAssertEqual(w.revive(), [])
        XCTAssertEqual(w.tick(dt: 1.0/60), [])
        XCTAssertEqual(w.hive.hp, -10)
        XCTAssertFalse(w.reviveUsed)
    }

    func testTickWhileDownedIsNoOp() {
        var w = downedWorld()
        let before = (w.mobs, w.hive, w.time, w.projectiles)
        XCTAssertEqual(w.tick(dt: 1.0/60), [])
        XCTAssertEqual(w.mobs, before.0); XCTAssertEqual(w.hive, before.1); XCTAssertEqual(w.time, before.2); XCTAssertEqual(w.projectiles, before.3)
        let statsBefore = w.hive.stats
        w.choose(UpgradeCatalog.milestone1[0])
        XCTAssertEqual(w.phase, .downed)
        XCTAssertEqual(w.hive.stats, statsBefore)
    }

    func testEndlessReviveContinues() {
        // The EndlessTests:42 trajectory: one pick (propolis_armor → maxHP 130) before the base hive falls at ≈ 28.5 s.
        var w = World(provider: .endless(EndlessConfig()), seed: 9, reviveAllowed: true)
        var downed = 0, over = 0
        var t = 0.0
        while t < 300 && w.phase != .downed {
            let ev = w.tick(dt: 1.0/60)
            downed += count(ev, .hiveDowned); over += count(ev, .gameOver)
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }
            t += 1.0/60
        }
        XCTAssertEqual(w.phase, .downed)
        XCTAssertEqual(w.hive.stats.maxHP, 130)
        let waves = w.wavesCleared
        _ = w.revive()
        XCTAssertEqual(w.hive.hp, 0.5 * w.hive.stats.maxHP, accuracy: 1e-9)
        XCTAssertEqual(w.hive.hp, 65, accuracy: 1e-9)   // half of the upgraded max, not of the base 100
        XCTAssertEqual(w.phase, .playing)
        while t < 300 && w.phase != .gameOver {
            let ev = w.tick(dt: 1.0/60)
            downed += count(ev, .hiveDowned); over += count(ev, .gameOver)
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }
            t += 1.0/60
        }
        XCTAssertEqual(downed, 1)
        XCTAssertEqual(over, w.phase == .gameOver ? 1 : 0)
        XCTAssertGreaterThanOrEqual(w.wavesCleared, waves)
        XCTAssertNotEqual(w.phase, .cleared)
        XCTAssertTrue(w.reviveUsed)
    }

    func testRunResultRevivedDefaultsFalse() {
        let id = UUID()
        let plain = RunResult(runID: id, levelId: 1, cleared: true, wavesCleared: 5, totalWaves: 5, coinsEarned: 80)
        XCTAssertFalse(plain.revived)
        let revived = RunResult(runID: id, levelId: 1, cleared: true, wavesCleared: 5, totalWaves: 5, coinsEarned: 80, revived: true)
        XCTAssertTrue(revived.revived)
        XCTAssertNotEqual(revived, plain)
        XCTAssertFalse(RunResult.endless(runID: id, wavesCleared: 3, coinsEarned: 72).revived)
        XCTAssertTrue(RunResult.endless(runID: id, wavesCleared: 3, coinsEarned: 72, revived: true).revived)
        // A revived clear counts (R5): ads accelerate, they never gate.
        var s = GameState()
        XCTAssertTrue(s.record(revived))
        XCTAssertEqual(s.highestClearedLevel, 1)
    }
}
