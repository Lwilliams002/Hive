import XCTest
@testable import HiveCore

final class ExpectedProgressTests: XCTestCase {
    func testCurveValues() {
        XCTAssertEqual(ExpectedProgress.totalTiers(forLevel: 1), 0)
        XCTAssertEqual(ExpectedProgress.totalTiers(forLevel: 5), 4)
        XCTAssertEqual(ExpectedProgress.totalTiers(forLevel: 10), 10)
        XCTAssertEqual(ExpectedProgress.totalTiers(forLevel: 20), 22)
        XCTAssertEqual(ExpectedProgress.totalTiers(forLevel: 30), 34)
    }

    func testLoadoutRoundRobin() {
        let six = ExpectedProgress.probeLoadout(totalTiers: 6)
        XCTAssertEqual(six.tier(of: .stinger), 2)
        XCTAssertEqual(six.tier(of: .swarm), 2)
        XCTAssertEqual(six.tier(of: .comb), 1)
        XCTAssertEqual(six.tier(of: .queen), 1)
        XCTAssertEqual(six.tier(of: .nectar), 0)

        // 50 > 40: the four combat tracks max out at 10 each; the remaining 10 are dropped (nectar is never assigned).
        let fifty = ExpectedProgress.probeLoadout(totalTiers: 50)
        for track in ExpectedProgress.probeTracks { XCTAssertEqual(fifty.tier(of: track), 10) }
        XCTAssertEqual(fifty.tier(of: .nectar), 0)
        XCTAssertEqual(fifty.totalTiers, 40)
    }
}
