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

    // MARK: - M4 (Task 5): levelsEnded counter and awardBonus ledger

    func testRecordIncrementsLevelsEndedOnce() {
        var s = GameState()
        XCTAssertEqual(s.levelsEnded, 0)
        let r = result(level: 1)
        XCTAssertTrue(s.record(r))
        XCTAssertEqual(s.levelsEnded, 1)
        XCTAssertFalse(s.record(r))
        XCTAssertEqual(s.levelsEnded, 1)
        XCTAssertTrue(s.record(result(level: 2, cleared: false, coins: 20)))
        XCTAssertEqual(s.levelsEnded, 2)
    }

    func testEndlessEndCountsAsLevelEnd() {
        var s = GameState()
        let r = RunResult.endless(runID: UUID(), wavesCleared: 3, coinsEarned: 10)
        XCTAssertTrue(s.record(r))
        XCTAssertEqual(s.levelsEnded, 1)
        XCTAssertFalse(s.record(r))
        XCTAssertEqual(s.levelsEnded, 1)
    }

    func testAwardBonusAddsCoinsOnce() {
        var s = GameState()
        let id = UUID()
        XCTAssertTrue(s.record(result(level: 1, coins: 80, id: id)))
        let recordedBefore = s.recordedRunIDs
        XCTAssertTrue(s.awardBonus(runID: id, coins: 80))
        XCTAssertEqual(s.coins, 160)
        XCTAssertEqual(s.bonusAwardedRunIDs, [id])
        XCTAssertEqual(s.recordedRunIDs, recordedBefore)
        XCTAssertFalse(s.awardBonus(runID: id, coins: 80))
        XCTAssertEqual(s.coins, 160)
        XCTAssertEqual(s.bonusAwardedRunIDs, [id])
        XCTAssertEqual(s.recordedRunIDs, recordedBefore)
    }

    func testAwardBonusRequiresRecordedRun() {
        var s = GameState()
        XCTAssertTrue(s.record(result(level: 1, coins: 80)))
        let before = s
        XCTAssertFalse(s.awardBonus(runID: UUID(), coins: 80))
        XCTAssertEqual(s.coins, 80)
        XCTAssertEqual(s.bonusAwardedRunIDs, [])
        XCTAssertEqual(s, before)
    }

    func testAwardBonusRefusesZeroCoins() {
        var s = GameState()
        let id = UUID()
        XCTAssertTrue(s.record(RunResult.endless(runID: id, wavesCleared: 0, coinsEarned: 0)))
        XCTAssertFalse(s.awardBonus(runID: id, coins: 0))
        XCTAssertEqual(s.coins, 0)
        XCTAssertEqual(s.bonusAwardedRunIDs, [])
    }

    func testBonusRunIDsCappedAt20() {
        var s = GameState()
        var ids: [UUID] = []
        for _ in 0..<25 {
            let id = UUID(); ids.append(id)
            XCTAssertTrue(s.record(result(level: 1, coins: 80, id: id)))
            XCTAssertTrue(s.awardBonus(runID: id, coins: 80))
        }
        XCTAssertEqual(s.coins, 4000)
        XCTAssertEqual(s.bonusAwardedRunIDs.count, 20)
        XCTAssertEqual(s.bonusAwardedRunIDs, Array(ids.suffix(20)))
        XCTAssertEqual(s.recordedRunIDs, Array(ids.suffix(20)))
    }
}
