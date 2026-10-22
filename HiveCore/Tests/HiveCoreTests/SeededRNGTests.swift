import XCTest
@testable import HiveCore

final class SeededRNGTests: XCTestCase {
    func testSameSeedSameSequence() {
        var a = SeededRNG(seed: 42), b = SeededRNG(seed: 42)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }
    func testDifferentSeedsDiffer() {
        var a = SeededRNG(seed: 1), b = SeededRNG(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }
    func testUnitDoubleInRange() {
        var r = SeededRNG(seed: 7)
        for _ in 0..<1000 { let d = r.unitDouble(); XCTAssert(d >= 0 && d < 1) }
    }
}
