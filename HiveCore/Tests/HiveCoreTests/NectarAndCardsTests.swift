import XCTest
import Foundation
@testable import HiveCore

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
