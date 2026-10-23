import XCTest
@testable import HiveCore

/// Shared headless difficulty probe: runs one level for every seed with a card-pick policy.
enum ProbeHarness {
    static let seeds = 1...20

    struct ProbeResult { var cleared = 0, bossReached = 0; var avgEndWave = 0.0 }

    /// `Hive/Resources/Levels` in the repo, found relative to this file.
    static var levelsDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        url = url.deletingLastPathComponent()   // HiveCoreTests
        url = url.deletingLastPathComponent()   // Tests
        url = url.deletingLastPathComponent()   // HiveCore
        url = url.deletingLastPathComponent()   // repo root
        return url.appendingPathComponent("Hive/Resources/Levels")
    }

    static func levelURL(_ id: Int) -> URL {
        levelsDirectory.appendingPathComponent(String(format: "level_%03d.json", id))
    }

    static func levelData(_ id: Int) throws -> Data {
        let url = levelURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(url.lastPathComponent) not found at \(url.path)")
        }
        return try Data(contentsOf: url)
    }

    static func loadLevel(_ id: Int) throws -> LevelDefinition {
        try LevelDefinition.load(from: try levelData(id))
    }

    static func runProbe(level: LevelDefinition, hiveStats: HiveStats = .base, startingCardCount: Int = 0,
                         cardPool: [UpgradeCard] = UpgradeCatalog.milestone1,
                         startingCardPool: [UpgradeCard] = UpgradeCatalog.milestone1,
                         dt: Double = 1.0 / 60, timeCap: Double = 300,
                         pick: (World, [UpgradeCard]) -> UpgradeCard) -> ProbeResult {
        var r = ProbeResult()
        var endWaveSum = 0
        for seed in seeds {
            var world = World(level: level, hiveStats: hiveStats, cardPool: cardPool,
                              startingCardCount: startingCardCount, startingCardPool: startingCardPool,
                              seed: UInt64(seed))
            var sawBoss = false
            var t = 0.0
            while t < timeCap {
                for case .waveStarted(_, let isBoss) in world.tick(dt: dt) where isBoss {
                    sawBoss = true
                }
                if case .pickingCards(let cards) = world.phase { world.choose(pick(world, cards)) }
                if world.phase == .cleared || world.phase == .gameOver { break }
                t += dt
            }
            if world.phase == .cleared { r.cleared += 1 }
            if sawBoss { r.bossReached += 1 }
            endWaveSum += world.director.waveNumber
        }
        r.avgEndWave = Double(endWaveSum) / Double(seeds.count)
        return r
    }

    /// Restricted to the six milestone-1 cards this is exactly the original level-1 greedy order.
    static let greedyPriority = ["swarm_call", "queens_wrath", "twin_stinger", "venom", "royal_guard", "guard_bees",
                                 "rapid_stingers", "pollen_cloud", "piercing", "honey_field", "thick_wax",
                                 "propolis_armor", "royal_jelly"]

    static func greedy(_ world: World, _ cards: [UpgradeCard]) -> UpgradeCard {
        if world.hive.hp < 0.4 * world.hive.stats.maxHP,
           let heal = cards.first(where: { $0.id == "royal_jelly" }) ?? cards.first(where: { $0.id == "propolis_armor" }) {
            return heal
        }
        return cards.min { (greedyPriority.firstIndex(of: $0.id) ?? 99) < (greedyPriority.firstIndex(of: $1.id) ?? 99) }!
    }
}
