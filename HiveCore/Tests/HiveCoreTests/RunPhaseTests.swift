import XCTest
import Foundation
@testable import HiveCore

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
    func testKillThatClearsLevelDoesNotOpenPick() {
        // the bear's 15 nectar crosses the first threshold (8) on the kill that also empties the level
        let bear = try! LevelDefinition.load(from: Data(#"{"id":2,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"bear","count":1,"interval":0}]}]}"#.utf8))
        var w = World(level: bear, hiveStats: HiveStats(maxHP: 100000, damage: 50, fireRate: 10), seed: 3)
        var ev: [GameEvent] = []; var t = 0.0
        while t < 40 && w.phase == .playing { ev += w.tick(dt: 1.0/60); t += 1.0/60 }
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertFalse(ev.contains(.nectarThreshold))
        XCTAssertEqual(ev.filter { $0 == .levelCleared }.count, 1)
        XCTAssertEqual(w.nectar.level, 1)   // the threshold still counts; only the pick is skipped
    }
    func testSecondThresholdOfferedAfterChoose() {
        // 7 wasps then a 1000 s gap; kill all 7 → nectar 7/8
        let lvl = try! LevelDefinition.load(from: Data(#"{"id":9,"name":"t","waves":[{"delay":0,"spawns":[{"type":"wasp","count":7,"interval":0}]},{"delay":1000,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#.utf8))
        var w = World(level: lvl, hiveStats: HiveStats(damage: 20, fireRate: 10, pierce: 1), seed: 2)
        var t = 0.0
        while t < 10 && !(w.director.waveNumber == 1 && w.mobs.isEmpty && t > 1) { _ = w.tick(dt: 1.0/60); t += 1.0/60 }
        XCTAssertEqual(w.phase, .playing)
        XCTAssertEqual(w.nectar.level, 0)
        XCTAssertEqual(w.nectar.current, 7)
        // bear (15) and hornet (3) at 1 hp on top of one pierce-1 projectile: 7+15 = 22 → crosses 8 (14 left); 14+3 = 17 → crosses 16 (1 left)
        w.debugAddMob(type: .bear, position: Vec2(200, 0))
        w.debugAddMob(type: .hornet, position: Vec2(200, 0))
        w.debugSetMob(index: 0, position: Vec2(200, 0), hp: 1)
        w.debugSetMob(index: 1, position: Vec2(200, 0), hp: 1)
        w.debugAddProjectile(at: Vec2(200, 0), velocity: .zero, damage: 5)
        let ev = w.tick(dt: 1.0/60)
        XCTAssertEqual(ev.filter { if case .mobKilled = $0 { return true }; return false }.count, 2)
        XCTAssertEqual(w.nectar.level, 2)
        guard case .pickingCards(let first) = w.phase else { return XCTFail("expected first pick, got \(w.phase)") }
        w.choose(first[0])
        guard case .pickingCards(let second) = w.phase else { return XCTFail("expected second pick, got \(w.phase)") }
        w.choose(second[0])
        XCTAssertEqual(w.phase, .playing)
    }
}
