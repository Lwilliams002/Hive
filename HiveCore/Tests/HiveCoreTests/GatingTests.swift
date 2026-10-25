import XCTest
import Foundation
@testable import HiveCore

final class GatingTests: XCTestCase {
    func testTierUnlockLevels() {
        for t in 1...5 { XCTAssertEqual(PermanentUpgrades.unlockLevel(forTier: t), 0) }
        for t in 6...8 { XCTAssertEqual(PermanentUpgrades.unlockLevel(forTier: t), 8) }
        for t in 9...10 { XCTAssertEqual(PermanentUpgrades.unlockLevel(forTier: t), 16) }
    }

    func testPurchaseRefusedWhenTierLocked() {
        var s = GameState(version: 1, coins: 99999,
                          upgrades: PermanentUpgrades(tiers: [.comb: 5]),
                          highestClearedLevel: 7, recordedRunIDs: [])
        XCTAssertEqual(s.purchaseBlock(for: .comb), .lockedUntil(level: 8))
        let before = s
        XCTAssertFalse(s.purchase(.comb))
        XCTAssertEqual(s, before)
        s.highestClearedLevel = 8
        XCTAssertNil(s.purchaseBlock(for: .comb))
        XCTAssertTrue(s.purchase(.comb))
        XCTAssertEqual(s.upgrades.tier(of: .comb), 6)
    }

    func testPurchaseBlockOrder() {
        var s = GameState(version: 1, coins: 0, upgrades: PermanentUpgrades(tiers: [.comb: 10, .swarm: 5]),
                          highestClearedLevel: 0, recordedRunIDs: [])
        XCTAssertEqual(s.purchaseBlock(for: .comb), .maxed)
        XCTAssertEqual(s.purchaseBlock(for: .swarm), .lockedUntil(level: 8))
        XCTAssertEqual(s.purchaseBlock(for: .stinger), .cannotAfford)
        s.coins = 100
        XCTAssertNil(s.purchaseBlock(for: .stinger))
    }

    func testEndlessUnlockedAtTen() {
        var s = GameState()
        s.highestClearedLevel = 9
        XCTAssertFalse(s.endlessUnlocked)
        s.highestClearedLevel = 10
        XCTAssertTrue(s.endlessUnlocked)
    }

    func testGameStateDecodesWithoutBestEndlessWave() throws {
        let url = Bundle.module.url(forResource: "save_v1", withExtension: "json", subdirectory: "Fixtures")!
        let s = try JSONDecoder().decode(GameState.self, from: Data(contentsOf: url))
        XCTAssertEqual(s.bestEndlessWave, 0)
        XCTAssertEqual(s.coins, 1234)
        XCTAssertEqual(s.levelsEnded, 0)
        XCTAssertEqual(s.lastInterstitialAtLevelsEnded, 0)
        XCTAssertNil(s.lastRewardedAdAt)
        XCTAssertFalse(s.consentPrompted)
        XCTAssertEqual(s.bonusAwardedRunIDs, [])
    }
}
