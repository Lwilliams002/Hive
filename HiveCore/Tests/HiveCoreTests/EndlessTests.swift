import XCTest
import Foundation
@testable import HiveCore

final class EndlessTests: XCTestCase {
    func count(_ w: WaveDefinition, _ t: MobType) -> Int { w.spawns.filter { $0.type == t }.reduce(0) { $0 + $1.count } }

    func testEndlessWaveFormula() {
        let c = EndlessConfig()
        let w1 = c.wave(at: 1)
        XCTAssertEqual(w1.spawns.map { $0.type }, [.wasp])
        XCTAssertEqual(count(w1, .wasp), 10)
        XCTAssertFalse(w1.isBoss)
        let w5 = c.wave(at: 5)
        XCTAssertEqual(count(w5, .wasp), 18)
        XCTAssertEqual(count(w5, .hornet), 2)
        XCTAssertEqual(count(w5, .beetle), 1)
        XCTAssertEqual(count(w5, .bear), 1)
        XCTAssertTrue(w5.isBoss)
        XCTAssertEqual(w5.hpScale, 1.3, accuracy: 1e-9)
        XCTAssertEqual(count(c.wave(at: 10), .hornetQueen), 1)
        XCTAssertEqual(count(c.wave(at: 15), .swarmMother), 1)
        XCTAssertEqual(count(c.wave(at: 20), .bear), 1)
        XCTAssertEqual(WaveProvider.endless(c).wave(at: 0), c.wave(at: 1))
        XCTAssertNil(WaveProvider.endless(c).count)
    }

    func testEndlessNeverClears() {
        let god = HiveStats(maxHP: 1_000_000, damage: 500, fireRate: 20, projectileCount: 3)
        var w = World(provider: .endless(EndlessConfig()), hiveStats: god, seed: 5)
        XCTAssertTrue(w.isEndless)
        var t = 0.0
        while t < 240 {
            _ = w.tick(dt: 1.0 / 60)
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }
            XCTAssertNotEqual(w.phase, .cleared)
            t += 1.0 / 60
        }
        XCTAssertGreaterThanOrEqual(w.wavesCleared, 10)
    }

    func testEndlessGameOverOnce() {
        var w = World(provider: .endless(EndlessConfig()), seed: 9)
        var over = 0
        var t = 0.0
        while t < 300 {
            let ev = w.tick(dt: 1.0 / 60)
            over += ev.filter { $0 == .gameOver }.count
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }
            t += 1.0 / 60
        }
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(over, 1)
    }

    func testEndlessCoins() {
        XCTAssertEqual(CoinRules.endlessCoins(wavesCleared: 3, multiplier: 1.0), 48)
        XCTAssertEqual(CoinRules.endlessCoins(wavesCleared: 3, multiplier: 1.5), 72)
        XCTAssertEqual(CoinRules.endlessCoins(wavesCleared: 0, multiplier: 1.5), 0)
    }

    func testRecordUpdatesBestEndlessWave() {
        var s = GameState()
        XCTAssertEqual(s.bestEndlessWave, 0)
        XCTAssertTrue(s.record(.endless(runID: UUID(), wavesCleared: 7, coinsEarned: 100)))
        XCTAssertEqual(s.bestEndlessWave, 7)
        s.record(.endless(runID: UUID(), wavesCleared: 5, coinsEarned: 50))
        XCTAssertEqual(s.bestEndlessWave, 7)
        s.record(.endless(runID: UUID(), wavesCleared: 9, coinsEarned: 10))
        XCTAssertEqual(s.bestEndlessWave, 9)
        XCTAssertEqual(s.coins, 160)
        XCTAssertEqual(s.highestClearedLevel, 0)
    }
}
