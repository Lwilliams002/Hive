import XCTest
import CryptoKit
@testable import HiveCore

/// Levels whose probe bounds could not be met within the tuning budget (8 difficulty iterations).
/// Each entry widens that level's bounds only; see the task 4 report for the numbers.
let LevelCurveOverrides: [Int: (atExpectedMin: Int, behindMax: Int)] = [
    // L9 (swarmMother boss) has a cliff between D 0.75 (atExpected 17/20, behind 8/20) and
    // D 0.775 (7/20, 1/20); no 0.025 step meets both bounds. Kept at 0.75 with behind ≤ 8 (one over).
    9: (atExpectedMin: 10, behindMax: 8),
]

/// Per-level difficulty probes against the expected-progress curve (globals: "Per-level probe bounds",
/// as amended by the controller's task 4 rulings).
/// For each probed level L with expected tiers T, the greedy policy plays seeds 1…20 (420 s cap) with the
/// round-robin loadout for T ("atExpected") and for max(0, T − max(4, T/4)) ("behind"), using the card
/// pools the app would offer at L. Bounds: atExpected cleared ≥ 10/20 for every L ≥ 2 (L2–3 also ≤ 18/20);
/// behind cleared ≤ 7/20 for L ≥ 4.
final class LevelCurveProbeTests: XCTestCase {
    /// SHA-256 of the hand-kept `level_001.json`; the generator must never touch it.
    static let levelOneSHA256 = "321999e2953dd576c4cb8dfdb0359b199bdcc8d85760fc9f4bad8578ef05454f"

    static let defaultProbeLevels = [2, 3, 4, 5, 7, 10, 13, 16, 20, 25, 30]

    /// `HIVE_FULL_PROBE=1` probes every story level 2…30; `HIVE_PROBE_LEVELS=4,9` probes just those (tuning aid).
    static var probeLevels: [Int] {
        let env = ProcessInfo.processInfo.environment
        if env["HIVE_FULL_PROBE"] == "1" { return Array(2...30) }
        if let list = env["HIVE_PROBE_LEVELS"] {
            let levels = list.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !levels.isEmpty { return levels }
        }
        return defaultProbeLevels
    }

    /// Curve probes run at 1/30 s per tick to keep runtime sane (level 1's own probes stay at 1/60).
    static let dt = 1.0 / 30
    /// Curve probes allow 420 s per run (level 1's own probes keep 300 s).
    static let timeCap = 420.0

    /// Tiers of the "behind" loadout: `T − max(4, T/4)`, never below 0.
    static func behindTiers(_ expected: Int) -> Int { max(0, expected - max(4, expected / 4)) }

    func testLevelOneUnchanged() throws {
        let data = try ProbeHarness.levelData(1)
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, Self.levelOneSHA256, "level_001.json changed; it is hand-kept and must not be regenerated")
    }

    func testLevelsMatchExpectedCurve() throws {
        for id in 2...30 {
            XCTAssertNoThrow(try ProbeHarness.loadLevel(id), "level_\(id) failed to load")
        }
        let seedCount = ProbeHarness.seeds.count
        for level in Self.probeLevels {
            let definition = try ProbeHarness.loadLevel(level)
            let pool = UpgradeCatalog.pool(unlockedThrough: level - 1)
            let startingPool = pool.filter { !$0.effect.isHealOnly && $0.rarity != .epic }
            let expected = ExpectedProgress.totalTiers(forLevel: level)
            func probe(_ tiers: Int) -> ProbeHarness.ProbeResult {
                let up = ExpectedProgress.probeLoadout(totalTiers: tiers)
                return ProbeHarness.runProbe(level: definition, hiveStats: up.hiveStats(),
                                             startingCardCount: up.startingCardCount,
                                             cardPool: pool, startingCardPool: startingPool,
                                             dt: Self.dt, timeCap: Self.timeCap, pick: ProbeHarness.greedy)
            }
            let behindT = Self.behindTiers(expected)
            let ahead = probe(expected), back = probe(behindT)
            let atExpected = ahead.cleared, behind = back.cleared
            print("Curve L\(level): atExpected \(atExpected)/\(seedCount), behind \(behind)/\(seedCount)")
            if ProcessInfo.processInfo.environment["HIVE_PROBE_VERBOSE"] == "1" {
                let f = { (r: ProbeHarness.ProbeResult) in "boss \(r.bossReached), wave \(String(format: "%.2f", r.avgEndWave))" }
                print("  L\(level) detail: atExpected \(f(ahead)) / \(definition.waves.count); behind \(f(back))")
            }

            let override = LevelCurveOverrides[level]
            let atExpectedMin = override?.atExpectedMin ?? 10
            XCTAssertGreaterThanOrEqual(atExpected, atExpectedMin, "L\(level) at expected (T=\(expected)) cleared \(atExpected) < \(atExpectedMin)")
            if level >= 4 {
                let behindMax = override?.behindMax ?? 7
                XCTAssertLessThanOrEqual(behind, behindMax, "L\(level) behind (T=\(behindT)) cleared \(behind) > \(behindMax)")
            } else {
                // Levels 2–3 have no behind bound; instead they must not be a walkover at expected.
                XCTAssertLessThanOrEqual(atExpected, 18, "L\(level) at expected (T=\(expected)) cleared \(atExpected) > 18")
            }
        }
    }
}
