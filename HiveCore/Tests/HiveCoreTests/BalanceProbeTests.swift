import XCTest
@testable import HiveCore

/// Headless difficulty probes for level 1 (the on-ramp): base stats, two card-pick policies.
/// First-card: a careless player clears sometimes. Greedy: a sensible player clears usually and nearly always reaches the boss.
/// Uses the milestone-1 card pool so these numbers stay fixed as cards are added.
final class BalanceProbeTests: XCTestCase {
    private var seedCount: Int { ProbeHarness.seeds.count }

    private func runProbe(hiveStats: HiveStats = .base, startingCardCount: Int = 0,
                          pick: (World, [UpgradeCard]) -> UpgradeCard) throws -> ProbeHarness.ProbeResult {
        ProbeHarness.runProbe(level: try ProbeHarness.loadLevel(1), hiveStats: hiveStats,
                              startingCardCount: startingCardCount,
                              cardPool: UpgradeCatalog.milestone1, startingCardPool: UpgradeCatalog.milestone1,
                              pick: pick)
    }

    func testLevelOneIsHardButNotImpossible() throws {
        let r = try runProbe { _, cards in cards[0] }
        print("BalanceProbe: cleared \(r.cleared) / \(seedCount), boss reached \(r.bossReached) / \(seedCount), avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertTrue((4...12).contains(r.cleared), "first-card cleared \(r.cleared) not in 4...12")
        XCTAssertGreaterThanOrEqual(r.bossReached, 1)
    }

    func testGreedyPolicyClearsLevelOneSometimes() throws {
        let r = try runProbe(pick: ProbeHarness.greedy)
        print("BalanceProbe(greedy): cleared \(r.cleared) / \(seedCount), boss reached \(r.bossReached) / \(seedCount), avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertTrue((10...18).contains(r.cleared), "greedy cleared \(r.cleared) not in 10...18")
        XCTAssertGreaterThanOrEqual(r.bossReached, 10)
    }

    func testGreedyPolicyAtMidGameUpgradesClearsLevelOneReliably() throws {
        let up = PermanentUpgrades(tiers: [.comb: 3, .stinger: 3, .swarm: 3, .queen: 3])
        let r = try runProbe(hiveStats: up.hiveStats(), startingCardCount: up.startingCardCount, pick: ProbeHarness.greedy)
        print("BalanceProbe(midgame): cleared \(r.cleared) / \(seedCount), boss reached \(r.bossReached) / \(seedCount), avg end wave \(String(format: "%.2f", r.avgEndWave))")
        XCTAssertGreaterThanOrEqual(r.cleared, 17, "mid-game cleared \(r.cleared) < 17")
    }
}
