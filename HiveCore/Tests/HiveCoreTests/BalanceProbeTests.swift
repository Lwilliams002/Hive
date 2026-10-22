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

    private struct ProbeResult { var cleared = 0, bossReached = 0; var avgEndWave = 0.0 }

    private func runProbe(pick: (World, [UpgradeCard]) -> UpgradeCard) throws -> ProbeResult {
        let level = try LevelDefinition.load(from: try levelData())
        var r = ProbeResult()
        var endWaveSum = 0
        for seed in 1...20 {
            var world = World(level: level, seed: UInt64(seed))
            var sawBoss = false
            var t = 0.0
            while t < 300 {
                for case .waveStarted(_, let isBoss) in world.tick(dt: 1.0 / 60) where isBoss {
                    sawBoss = true
                }
                if case .pickingCards(let cards) = world.phase { world.choose(pick(world, cards)) }
                if world.phase == .cleared || world.phase == .gameOver { break }
                t += 1.0 / 60
            }
            if world.phase == .cleared { r.cleared += 1 }
            if sawBoss { r.bossReached += 1 }
            endWaveSum += world.director.waveNumber
        }
        r.avgEndWave = Double(endWaveSum) / 20
        return r
    }

    func testLevelOneIsHardButNotImpossible() throws {
        let r = try runProbe { _, cards in cards[0] }
        print("BalanceProbe: cleared \(r.cleared) / 20, boss reached \(r.bossReached) / 20, avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertLessThanOrEqual(r.cleared, 6)
        XCTAssertGreaterThanOrEqual(r.bossReached, 1)
    }

    func testGreedyPolicyClearsLevelOneSometimes() throws {
        let priority = ["twin_stinger", "venom", "rapid_stingers", "piercing", "propolis_armor", "royal_jelly"]
        let r = try runProbe { world, cards in
            if world.hive.hp < 0.4 * world.hive.stats.maxHP,
               let heal = cards.first(where: { $0.id == "royal_jelly" }) ?? cards.first(where: { $0.id == "propolis_armor" }) {
                return heal
            }
            return cards.min { (priority.firstIndex(of: $0.id) ?? 99) < (priority.firstIndex(of: $1.id) ?? 99) }!
        }
        print("BalanceProbe(greedy): cleared \(r.cleared) / 20, boss reached \(r.bossReached) / 20, avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertGreaterThanOrEqual(r.cleared, 4)
        XCTAssertLessThanOrEqual(r.cleared, 14)
    }
}
