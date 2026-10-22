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
}
