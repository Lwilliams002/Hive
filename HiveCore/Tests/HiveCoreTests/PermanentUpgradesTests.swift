import XCTest
import Foundation
@testable import HiveCore

final class PermanentUpgradesTests: XCTestCase {
    func testCostsTable() {
        XCTAssertEqual((1...10).map { PermanentUpgrades.cost(forTier: $0) },
                       [50, 140, 290, 500, 770, 1100, 1490, 1940, 2450, 3020])
    }

    func testStatsAtZeroEqualBase() {
        let u = PermanentUpgrades()
        XCTAssertEqual(u.hiveStats(), HiveStats.base)
        XCTAssertEqual(u.coinMultiplier, 1)
        XCTAssertEqual(u.startingCardCount, 0)
        XCTAssertEqual(u.visualTier, 1)
    }

    func testStatsDerivation() {
        let u = PermanentUpgrades(tiers: [.comb: 3, .stinger: 2, .swarm: 8, .nectar: 5, .queen: 7])
        let s = u.hiveStats()
        XCTAssertEqual(s.maxHP, 145)
        XCTAssertEqual(s.damage, 13)
        XCTAssertEqual(s.fireRate, 3.2, accuracy: 1e-9)
        XCTAssertEqual(s.projectileCount, 3)
        XCTAssertEqual(u.coinMultiplier, 1.5, accuracy: 1e-9)
        XCTAssertEqual(u.startingCardCount, 2)
        XCTAssertEqual(u.totalTiers, 25)
        XCTAssertEqual(u.visualTier, 6)
    }

    func testSwarmProjectileThresholds() {
        func count(_ t: Int) -> Int { PermanentUpgrades(tiers: [.swarm: t]).hiveStats().projectileCount }
        XCTAssertEqual(count(3), 1)
        XCTAssertEqual(count(4), 2)
        XCTAssertEqual(count(7), 2)
        XCTAssertEqual(count(8), 3)
    }

    func testRaiseClampsAtMax() {
        var u = PermanentUpgrades()
        for _ in 0..<11 { u.raise(.comb) }
        XCTAssertEqual(u.tier(of: .comb), 10)
        XCTAssertNil(u.nextCost(for: .comb))
    }

    func testCodableRoundTripAndMissingTracks() throws {
        let u = PermanentUpgrades(tiers: [.comb: 3, .stinger: 2, .swarm: 8, .nectar: 5, .queen: 7])
        let data = try JSONEncoder().encode(u)
        XCTAssertEqual(try JSONDecoder().decode(PermanentUpgrades.self, from: data), u)

        XCTAssertEqual(try JSONDecoder().decode(PermanentUpgrades.self,
                                                from: JSONEncoder().encode(PermanentUpgrades())), PermanentUpgrades())
        XCTAssertEqual(PermanentUpgrades(tiers: [.comb: 0]), PermanentUpgrades())

        let partial = try JSONDecoder().decode(PermanentUpgrades.self,
                                               from: Data(#"{"tiers":{"comb":2}}"#.utf8))
        XCTAssertEqual(partial.tier(of: .comb), 2)
        for t in UpgradeTrack.allCases where t != .comb { XCTAssertEqual(partial.tier(of: t), 0) }
    }

    func testVisualTierBounds() {
        var all = [UpgradeTrack: Int]()
        for t in UpgradeTrack.allCases { all[t] = 10 }
        XCTAssertEqual(PermanentUpgrades(tiers: all).visualTier, 11)
        XCTAssertEqual(PermanentUpgrades().visualTier, 1)
        XCTAssertEqual(PermanentUpgrades(tiers: [.comb: 4]).visualTier, 1)
        XCTAssertEqual(PermanentUpgrades(tiers: [.comb: 5]).visualTier, 2)
    }

    func testTiersToNextLook() {
        XCTAssertEqual(PermanentUpgrades().tiersToNextLook, 5)
        XCTAssertEqual(PermanentUpgrades(tiers: [.comb: 3]).tiersToNextLook, 2)
        XCTAssertEqual(PermanentUpgrades(tiers: [.comb: 5]).tiersToNextLook, 5)
        var all = [UpgradeTrack: Int]()
        for t in UpgradeTrack.allCases { all[t] = 10 }
        XCTAssertEqual(PermanentUpgrades(tiers: all).tiersToNextLook, 0)
        all[.queen] = 9
        XCTAssertEqual(PermanentUpgrades(tiers: all).tiersToNextLook, 1)
        XCTAssertTrue(CardEffect.healFraction(0.5).isHealOnly)
        XCTAssertTrue(CardEffect.addMaxHP(30, healBy: 30).isHealOnly)
        XCTAssertFalse(CardEffect.damageMultiplier(1.3).isHealOnly)
    }

    func testEffectDescriptions() {
        let u = PermanentUpgrades()
        XCTAssertEqual(u.effectDescription(for: .comb, atTier: 3), "HP 145")
        XCTAssertEqual(u.effectDescription(for: .stinger, atTier: 3), "Damage 14.5")
        XCTAssertEqual(u.effectDescription(for: .stinger, atTier: 2), "Damage 13")
        XCTAssertEqual(u.effectDescription(for: .swarm, atTier: 1), "Fire rate 2.2/s · 1 stinger")
        XCTAssertEqual(u.effectDescription(for: .swarm, atTier: 8), "Fire rate 3.2/s · 3 stingers")
        XCTAssertEqual(u.effectDescription(for: .nectar, atTier: 3), "+30% coins")
        XCTAssertEqual(u.effectDescription(for: .queen, atTier: 3), "1 starting card")
        XCTAssertEqual(u.effectDescription(for: .queen, atTier: 0), "No starting cards")
    }
}
