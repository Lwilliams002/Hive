import XCTest
@testable import HiveCore

final class MobTests: XCTestCase {
    func testStatsTable() {
        XCTAssertEqual(MobType.wasp.stats, MobStats(maxHP: 20, speed: 90, contactDamage: 10, radius: 10, nectar: 1, isBoss: false))
        XCTAssertEqual(MobType.hornet.stats, MobStats(maxHP: 60, speed: 55, contactDamage: 20, radius: 14, nectar: 3, isBoss: false))
        XCTAssertEqual(MobType.bear.stats, MobStats(maxHP: 450, speed: 28, contactDamage: 40, radius: 30, nectar: 15, isBoss: true))
    }
    func testMobDecodesFromRawValue() {
        XCTAssertEqual(try JSONDecoder().decode(MobType.self, from: Data("\"hornet\"".utf8)), .hornet)
    }
}
