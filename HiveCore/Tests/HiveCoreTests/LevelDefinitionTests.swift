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
    func testRejectsZeroCountAndNegativeNumbers() {
        let bad = [
            #"{"id":1,"name":"x","waves":[{"delay":0,"spawns":[{"type":"wasp","count":0,"interval":0}]}]}"#,
            #"{"id":1,"name":"x","waves":[{"delay":0,"spawns":[{"type":"wasp","count":2,"interval":-1}]}]}"#,
            #"{"id":1,"name":"x","waves":[{"delay":-0.5,"spawns":[{"type":"wasp","count":2,"interval":0}]}]}"#,
            #"{"id":1,"name":"x","waves":[{"delay":0,"hpScale":0,"spawns":[{"type":"wasp","count":2,"interval":0}]}]}"#,
        ]
        for json in bad {
            XCTAssertThrowsError(try LevelDefinition.load(from: Data(json.utf8)), json) {
                XCTAssertEqual($0 as? LevelError, .invalid("level 1 wave 0 has invalid numbers"))
            }
        }
    }
    func testHpScaleDefaultsToOneAndDecodes() throws {
        let level = try LevelDefinition.load(from: Data(#"{"id":2,"name":"x","waves":[{"delay":0,"spawns":[{"type":"beetle","count":1,"interval":0}]},{"delay":1,"hpScale":1.5,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#.utf8))
        XCTAssertEqual(level.waves[0].hpScale, 1.0)
        XCTAssertEqual(level.waves[1].hpScale, 1.5)
        XCTAssertEqual(WaveDefinition(delay: 0, spawns: []).hpScale, 1.0)
        // mobs spawned in a scaled wave get scaled hp and maxHP
        let scaled = LevelDefinition(id: 3, name: "x", waves: [WaveDefinition(delay: 0, spawns: [SpawnGroup(type: .wasp, count: 1, interval: 0)], hpScale: 1.5)])
        var w = World(level: scaled, seed: 1)
        _ = w.tick(dt: 1.0/60)
        XCTAssertEqual(w.mobs[0].maxHP, 30, accuracy: 1e-9)
        XCTAssertEqual(w.mobs[0].hp, 30, accuracy: 1e-9)
        XCTAssertEqual(w.mobs[0].hpScale, 1.5, accuracy: 1e-9)
    }
}
