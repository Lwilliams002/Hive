import XCTest
import Foundation
@testable import HiveCore

final class LevelDefinitionTests: XCTestCase {
    func fixture() throws -> Data {
        let url = Bundle.module.url(forResource: "level_test", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }
    func testDecodesFixture() throws {
        let level = try LevelDefinition.load(from: fixture())
        XCTAssertEqual(level.id, 99)
        XCTAssertEqual(level.waves.count, 2)
        XCTAssertFalse(level.waves[0].isBoss)
        XCTAssertTrue(level.waves[1].isBoss)
        XCTAssertEqual(level.waves[1].spawns[0], SpawnGroup(type: .bear, count: 1, interval: 0))
    }
    func testMalformedLevelJSONThrows() {
        XCTAssertThrowsError(try LevelDefinition.load(from: Data("{not json".utf8)))
    }
    func testEmptyWavesThrowsInvalid() {
        let data = Data(#"{"id":1,"name":"x","waves":[]}"#.utf8)
        XCTAssertThrowsError(try LevelDefinition.load(from: data)) { XCTAssertEqual($0 as? LevelError, .invalid("level 1 has no waves")) }
    }
}
