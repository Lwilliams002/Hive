import XCTest
import CryptoKit
@testable import HiveCore

/// Levels whose probe bounds could not be met within the tuning budget (difficulty tuned in 0.025 D steps,
/// at most 10 iterations per level). Each entry widens that level's bounds only; see the task 4 report.
let LevelCurveOverrides: [Int: (atExpectedMin: Int, atExpectedMax: Int, behindMax: Int)] = [
    // Each level below sits on a cliff between adjacent 0.025 D steps; the kept D misses by the noted margin.
    // The behind average-end-wave guard (≥ 2.0) is never overridden.
    // L4 (bear): 1.25 → 16/9; 1.2 → 17/12, 1.275 → 17/12, 1.3 → 13/0 with behind dying in wave 1. Behind 2 over.
    4: (atExpectedMin: 10, atExpectedMax: 19, behindMax: 9),
    // L11 (hornetQueen): T=12 reaches queen 3 (a starting card) over behind T=8. 0.85 → 20/6;
    // 0.875 → 19/1 with behind dying in wave 1 (avg end wave 1.6). atExpected 1 over.
    11: (atExpectedMin: 10, atExpectedMax: 20, behindMax: 7),
    // L13 (bear): T=14 crosses swarm 4 (2nd projectile) and queen 3 (starting card) over behind T=10, so
    // atExpected is 20/20 at every D tried (0.85–1.05); above 1.0 behind dies in wave 1. 0.9 → 20/4. atExpected 1 over.
    13: (atExpectedMin: 10, atExpectedMax: 20, behindMax: 7),
    // L14 (hornetQueen): same threshold cliff as L13 (T=15 vs 11). 0.875 → 20/7; higher D keeps 20/20 until
    // behind dies in wave 1 (1.05 → 19/1, avg end wave 1.35). atExpected 1 over.
    14: (atExpectedMin: 10, atExpectedMax: 20, behindMax: 7),
    // L16 (bear): 1.175 → 14/8; 1.15 → 18/8, 1.2 → 10/0 with behind dying in wave 1. Behind 1 over.
    16: (atExpectedMin: 10, atExpectedMax: 19, behindMax: 8),
    // L19 (bear): 1.025 → 20/8; 1.0 → 20/9, 1.05 → 19/1 with behind dying in wave 1. atExpected 1 over, behind 1 over.
    19: (atExpectedMin: 10, atExpectedMax: 20, behindMax: 8),
    // L23 (hornetQueen): 1.0 → 19/8; 1.025 → 20/7, 1.05 → 16/2 with behind dying in wave 1. Behind 1 over.
    23: (atExpectedMin: 10, atExpectedMax: 19, behindMax: 8),
]

/// Per-level difficulty probes against the expected-progress curve (globals: "Per-level probe bounds",
/// as amended by the controller's task 4 rulings).
/// For each probed level L with expected tiers T, the greedy policy plays seeds 1…20 (dt 1/30, 420 s cap)
/// with the round-robin loadout for T ("atExpected") and for max(0, T − max(4, min(6, T/4))) ("behind"),
/// using the card pools the app would offer at L. Bounds: atExpected cleared ≥ 10/20 for every L ≥ 2
/// (L2–3 also ≤ 18/20); for L ≥ 4 behind cleared ≤ 7/20, plus cliff guards: atExpected ≤ 19/20 and the
/// behind loadout's average end wave ≥ 2.0 (a behind player should not die in wave 1).
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

    /// Tiers of the "behind" loadout: `T − max(4, min(6, T/4))`, never below 0.
    static func behindTiers(_ expected: Int) -> Int { max(0, expected - max(4, min(6, expected / 4))) }

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
            print("Curve L\(level): atExpected \(atExpected)/\(seedCount), behind \(behind)/\(seedCount)"
                  + " (behind avg end wave \(String(format: "%.2f", back.avgEndWave)))")
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
                // Cliff guards: not a walkover at expected, and a behind player gets past wave 1 on average.
                let atExpectedMax = override?.atExpectedMax ?? 19
                XCTAssertLessThanOrEqual(atExpected, atExpectedMax, "L\(level) at expected (T=\(expected)) cleared \(atExpected) > \(atExpectedMax)")
                XCTAssertGreaterThanOrEqual(back.avgEndWave, 2.0, "L\(level) behind (T=\(behindT)) avg end wave \(back.avgEndWave) < 2.0")
            } else {
                // Levels 2–3 have no behind bound; instead they must not be a walkover at expected.
                XCTAssertLessThanOrEqual(atExpected, 18, "L\(level) at expected (T=\(expected)) cleared \(atExpected) > 18")
            }
        }
    }
}
