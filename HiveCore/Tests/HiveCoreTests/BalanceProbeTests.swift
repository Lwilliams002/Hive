import XCTest
@testable import HiveCore

/// Headless difficulty probe for level 1: base stats, always pick the first card offered.
/// Intent (spec 5.3): hard but not impossible.
final class BalanceProbeTests: XCTestCase {
    private func levelData() throws -> Data {
        var url = URL(fileURLWithPath: #filePath)
        url = url.deletingLastPathComponent()   // HiveCoreTests
        url = url.deletingLastPathComponent()   // Tests
        url = url.deletingLastPathComponent()   // HiveCore
        url = url.deletingLastPathComponent()   // repo root
        url = url.appendingPathComponent("Hive/Resources/Levels/level_001.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("level_001.json not found at \(url.path)")
        }
        return try Data(contentsOf: url)
    }

    func testLevelOneIsHardButNotImpossible() throws {
        let level = try LevelDefinition.load(from: try levelData())
        var cleared = 0, bossReached = 0, endWaveSum = 0
        for seed in 1...20 {
            var world = World(level: level, seed: UInt64(seed))
            var sawBoss = false
            var t = 0.0
            while t < 300 {
                for case .waveStarted(_, let isBoss) in world.tick(dt: 1.0 / 60) where isBoss {
                    sawBoss = true
                }
                if case .pickingCards(let cards) = world.phase { world.choose(cards[0]) }
                if world.phase == .cleared || world.phase == .gameOver { break }
                t += 1.0 / 60
            }
            if world.phase == .cleared { cleared += 1 }
            if sawBoss { bossReached += 1 }
            endWaveSum += world.director.waveNumber
        }
        let avg = Double(endWaveSum) / 20
        print("BalanceProbe: cleared \(cleared) / 20, boss reached \(bossReached) / 20, avg end wave \(String(format: "%.2f", avg))")
        XCTAssertLessThanOrEqual(cleared, 6)
        XCTAssertGreaterThanOrEqual(bossReached, 1)
    }
}
