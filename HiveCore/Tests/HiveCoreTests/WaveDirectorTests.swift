import XCTest
import Foundation
@testable import HiveCore

final class WaveDirectorTests: XCTestCase {
    var level: LevelDefinition { try! LevelDefinition.load(from: try! Data(contentsOf: Bundle.module.url(forResource: "level_test", withExtension: "json", subdirectory: "Fixtures")!)) }
    func testNothingSpawnsBeforeFirstDelay() {
        var d = WaveDirector(level: level)
        XCTAssertEqual(d.tick(dt: 0.9, aliveMobs: 0), [])
        XCTAssertEqual(d.waveNumber, 1); XCTAssertEqual(d.totalWaves, 2)
    }
    func testFirstGroupSpawnsOnIntervalFromWaveStart() {
        var d = WaveDirector(level: level)
        XCTAssertEqual(d.tick(dt: 1.0, aliveMobs: 0), [.wasp])     // wave starts, first spawn immediate
        XCTAssertEqual(d.tick(dt: 0.4, aliveMobs: 1), [])
        XCTAssertEqual(d.tick(dt: 0.1, aliveMobs: 1), [.wasp])
        XCTAssertEqual(d.tick(dt: 0.5, aliveMobs: 2), [.wasp])
        XCTAssertEqual(d.tick(dt: 5.0, aliveMobs: 3), [])          // all issued, mobs alive → no next wave
        XCTAssertFalse(d.isBossWave)
    }
    func testNextWaveWaitsForClearThenDelay() {
        var d = WaveDirector(level: level)
        _ = d.tick(dt: 1.0, aliveMobs: 0); _ = d.tick(dt: 1.0, aliveMobs: 1)   // wave 1 fully issued
        XCTAssertEqual(d.tick(dt: 1.9, aliveMobs: 0), [])           // delay 2.0 not yet elapsed
        let spawned = d.tick(dt: 0.1, aliveMobs: 0)
        XCTAssertEqual(Set(spawned), Set([.bear, .wasp]))           // interval-0 group + first of wasp group
        XCTAssertTrue(d.isBossWave); XCTAssertEqual(d.waveNumber, 2)
    }
    func testAllSpawnsIssued() {
        var d = WaveDirector(level: level)
        _ = d.tick(dt: 1.0, aliveMobs: 0); _ = d.tick(dt: 1.0, aliveMobs: 1)
        _ = d.tick(dt: 2.0, aliveMobs: 0); _ = d.tick(dt: 1.0, aliveMobs: 3)
        XCTAssertTrue(d.allSpawnsIssued)
        XCTAssertEqual(d.tick(dt: 10, aliveMobs: 0), [])
    }
}
