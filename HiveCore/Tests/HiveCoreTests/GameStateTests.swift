import XCTest
import Foundation
@testable import HiveCore

final class GameStateTests: XCTestCase {
    private func result(level: Int, cleared: Bool = true, coins: Int = 80, id: UUID = UUID()) -> RunResult {
        RunResult(runID: id, levelId: level, cleared: cleared, wavesCleared: 5, totalWaves: 5, coinsEarned: coins)
    }

    func testCoinRulesExamples() {
        XCTAssertEqual(CoinRules.coins(levelId: 1, wavesCleared: 5, cleared: true, multiplier: 1.0), 80)
        XCTAssertEqual(CoinRules.coins(levelId: 1, wavesCleared: 3, cleared: false, multiplier: 1.0), 24)
        XCTAssertEqual(CoinRules.coins(levelId: 3, wavesCleared: 6, cleared: true, multiplier: 1.3), 172)
    }

    func testPurchaseDeductsAndRaises() {
        var s = GameState(); s.coins = 200
        XCTAssertTrue(s.purchase(.comb))
        XCTAssertEqual(s.coins, 150)
        XCTAssertEqual(s.upgrades.tier(of: .comb), 1)
        XCTAssertTrue(s.purchase(.comb))
        XCTAssertEqual(s.coins, 10)
        XCTAssertEqual(s.upgrades.tier(of: .comb), 2)
    }

    func testPurchaseRefusedWhenPoor() {
        var s = GameState(); s.coins = 49
        XCTAssertFalse(s.purchase(.comb))
        XCTAssertEqual(s.coins, 49)
        XCTAssertEqual(s.upgrades.tier(of: .comb), 0)
    }

    func testPurchaseRefusedAtMaxTier() {
        var s = GameState(); s.coins = 99999
        s.upgrades = PermanentUpgrades(tiers: [.comb: 10])
        XCTAssertFalse(s.purchase(.comb))
        XCTAssertEqual(s.coins, 99999)
        XCTAssertEqual(s.upgrades.tier(of: .comb), 10)
    }

    func testRecordAddsCoinsAndProgress() {
        var s = GameState()
        XCTAssertTrue(s.record(result(level: 1)))
        XCTAssertEqual(s.coins, 80)
        XCTAssertEqual(s.highestClearedLevel, 1)
        XCTAssertEqual(s.currentLevel, 2)
    }

    func testRecordIsIdempotentPerRunID() {
        var s = GameState()
        let r = result(level: 1)
        XCTAssertTrue(s.record(r))
        XCTAssertFalse(s.record(r))
        XCTAssertEqual(s.coins, 80)
    }

    func testReplayPaysButDoesNotRegress() {
        var s = GameState(); s.highestClearedLevel = 3
        s.record(result(level: 1, cleared: true, coins: 50))
        XCTAssertEqual(s.coins, 50)
        XCTAssertEqual(s.highestClearedLevel, 3)
        s.record(result(level: 2, cleared: false, coins: 20))
        XCTAssertEqual(s.coins, 70)
        XCTAssertEqual(s.highestClearedLevel, 3)
    }

    func testRecordedRunIDsCappedAt20() {
        var s = GameState()
        var ids: [UUID] = []
        for _ in 0..<25 { let id = UUID(); ids.append(id); s.record(result(level: 1, id: id)) }
        XCTAssertEqual(s.recordedRunIDs.count, 20)
        XCTAssertEqual(s.recordedRunIDs, Array(ids.suffix(20)))
    }
}
