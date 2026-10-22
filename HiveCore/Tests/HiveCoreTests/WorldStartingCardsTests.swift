import XCTest
import Foundation
@testable import HiveCore

final class WorldStartingCardsTests: XCTestCase {
    func tenWasps() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":3,"name":"t","waves":[{"delay":0,"spawns":[{"type":"wasp","count":10,"interval":0}]}]}"#.utf8)) }
    func card(_ id: String) -> UpgradeCard { UpgradeCatalog.milestone1.first { $0.id == id }! }

    func testStartingCardsAppliedAtInit() {
        let w = World(level: tenWasps(), cardPool: [card("venom")], startingCardCount: 1, seed: 1)
        XCTAssertEqual(w.hive.stats.damage, 13, accuracy: 1e-9)
        XCTAssertEqual(w.startingCards.map(\.id), ["venom"])
    }
    func testStartingCardsZeroByDefault() {
        let w = World(level: tenWasps(), seed: 1)
        XCTAssertTrue(w.startingCards.isEmpty)
        XCTAssertEqual(w.hive.stats.damage, HiveStats.base.damage, accuracy: 1e-9)
    }
    func testCardPoolUsedForPicks() {
        let pool = [card("rapid_stingers"), card("venom"), card("twin_stinger")]
        var w = World(level: tenWasps(), hiveStats: HiveStats(damage: 20, fireRate: 10, projectileCount: 3), cardPool: pool, seed: 2)
        var t = 0.0
        while t < 30 { w.tick(dt: 1.0/60); t += 1.0/60; if case .pickingCards = w.phase { break } }
        guard case .pickingCards(let cards) = w.phase else { return XCTFail("expected pickingCards") }
        XCTAssertFalse(cards.isEmpty)
        for c in cards { XCTAssertTrue(pool.contains { $0.id == c.id }) }
    }
    func testRunIDUniquePerWorld() {
        XCTAssertNotEqual(World(level: tenWasps(), seed: 1).runID, World(level: tenWasps(), seed: 1).runID)
    }
    func testStartingCountLargerThanPoolIsClamped() {
        let w = World(level: tenWasps(), cardPool: [card("venom"), card("piercing")], startingCardCount: 3, seed: 1)
        XCTAssertEqual(w.startingCards.count, 2)
    }
}
