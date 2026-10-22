import XCTest
@testable import HiveCore

final class Vec2Tests: XCTestCase {
    func testLengthAndNormalized() {
        let v = Vec2(3, 4)
        XCTAssertEqual(v.length, 5, accuracy: 1e-9)
        XCTAssertEqual(v.normalized.x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(v.normalized.y, 0.8, accuracy: 1e-9)
    }
    func testNormalizedOfZeroIsZero() {
        XCTAssertEqual(Vec2.zero.normalized, .zero)
    }
    func testDistance() {
        XCTAssertEqual(Vec2(1, 1).distance(to: Vec2(4, 5)), 5, accuracy: 1e-9)
    }
}
