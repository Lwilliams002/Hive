import XCTest
@testable import HiveCore

/// Headless difficulty probes for level 1 (the on-ramp): base stats, two card-pick policies.
/// First-card: a careless player clears sometimes. Greedy: a sensible player clears usually and nearly always reaches the boss.
final class BalanceProbeTests: XCTestCase {
    static let seeds = 1...20
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
        for seed in Self.seeds {
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
        r.avgEndWave = Double(endWaveSum) / Double(Self.seeds.count)
        return r
    }

    func testLevelOneIsHardButNotImpossible() throws {
        let r = try runProbe { _, cards in cards[0] }
        print("BalanceProbe: cleared \(r.cleared) / \(Self.seeds.count), boss reached \(r.bossReached) / \(Self.seeds.count), avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertTrue((4...12).contains(r.cleared), "first-card cleared \(r.cleared) not in 4...12")
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
        print("BalanceProbe(greedy): cleared \(r.cleared) / \(Self.seeds.count), boss reached \(r.bossReached) / \(Self.seeds.count), avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertTrue((10...18).contains(r.cleared), "greedy cleared \(r.cleared) not in 10...18")
        XCTAssertGreaterThanOrEqual(r.bossReached, 10)
    }
}
