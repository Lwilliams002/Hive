import XCTest
import Foundation
@testable import HiveCore

final class SaveStoreTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func testLoadNilWhenNoFile() throws {
        XCTAssertNil(try FileSaveStore(directory: dir).load())
    }

    func testSaveRoundTrip() throws {
        let store = FileSaveStore(directory: dir)
        var s = GameState(); s.coins = 123
        s.upgrades = PermanentUpgrades(tiers: [.comb: 2])
        s.highestClearedLevel = 4
        s.recordedRunIDs = [UUID(), UUID()]
        s.levelsEnded = 7
        s.lastInterstitialAtLevelsEnded = 4
        s.lastRewardedAdAt = 1_700_000_000.5
        s.consentPrompted = true
        s.bonusAwardedRunIDs = [UUID()]
        try store.save(s)
        XCTAssertEqual(try store.load(), s)
    }

    func testSaveIsAtomicAndCreatesDirectory() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
        let store = FileSaveStore(directory: dir)
        try store.save(GameState())
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testCorruptFileStartsFreshAndKeepsBackup() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = FileSaveStore(directory: dir)
        try Data("{not json".utf8).write(to: store.fileURL)
        do {
            _ = try store.load()
            XCTFail("expected throw")
        } catch SaveError.corrupt(let backupPath) {
            XCTAssertEqual(try String(contentsOfFile: backupPath, encoding: .utf8), "{not json")
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        }
    }

    func testUnknownVersionStartsFresh() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = FileSaveStore(directory: dir)
        var s = GameState(); s.version = 99
        try JSONEncoder().encode(s).write(to: store.fileURL)
        do {
            _ = try store.load()
            XCTFail("expected throw")
        } catch SaveError.corrupt {
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        }
    }

    func testInMemoryStore() throws {
        let store = InMemorySaveStore()
        XCTAssertNil(try store.load())
        var s = GameState(); s.coins = 7
        try store.save(s)
        XCTAssertEqual(try store.load(), s)
        XCTAssertEqual(store.stored, s)
    }

    func testVersionBelowOneStartsFresh() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = FileSaveStore(directory: dir)
        try Data(#"{"version":0,"coins":5}"#.utf8).write(to: store.fileURL)
        do {
            _ = try store.load()
            XCTFail("expected throw")
        } catch SaveError.corrupt {
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        }
    }

    func testDecodesCommittedV1Fixture() throws {
        let url = Bundle.module.url(forResource: "save_v1", withExtension: "json", subdirectory: "Fixtures")!
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = FileSaveStore(directory: dir)
        try FileManager.default.copyItem(at: url, to: store.fileURL)
        let s = try XCTUnwrap(try store.load())
        XCTAssertEqual(s.version, 1)
        XCTAssertEqual(s.coins, 1234)
        XCTAssertEqual(s.upgrades.tier(of: .comb), 2)
        XCTAssertEqual(s.upgrades.tier(of: .swarm), 4)
        XCTAssertEqual(s.upgrades.tier(of: .stinger), 0)
        XCTAssertEqual(s.upgrades.tier(of: .nectar), 0)
        XCTAssertEqual(s.upgrades.tier(of: .queen), 0)
        XCTAssertEqual(s.highestClearedLevel, 3)
        XCTAssertEqual(s.recordedRunIDs, [UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!,
                                          UUID(uuidString: "0E984725-C51C-4BF4-9960-E1C80E27ABA0")!])
    }

    func testDecodesSaveMissingNewFields() throws {
        let s = try JSONDecoder().decode(GameState.self, from: Data(#"{"version":1,"coins":5}"#.utf8))
        XCTAssertEqual(s.version, 1)
        XCTAssertEqual(s.coins, 5)
        XCTAssertEqual(s.upgrades, PermanentUpgrades())
        XCTAssertEqual(s.highestClearedLevel, 0)
        XCTAssertEqual(s.recordedRunIDs, [])
        XCTAssertEqual(s.levelsEnded, 0)
        XCTAssertEqual(s.lastInterstitialAtLevelsEnded, 0)
        XCTAssertNil(s.lastRewardedAdAt)
        XCTAssertFalse(s.consentPrompted)
        XCTAssertEqual(s.bonusAwardedRunIDs, [])
    }

    func testDecodesCommittedM4Fixture() throws {
        let url = Bundle.module.url(forResource: "save_v1_m4", withExtension: "json", subdirectory: "Fixtures")!
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = FileSaveStore(directory: dir)
        try FileManager.default.copyItem(at: url, to: store.fileURL)
        let s = try XCTUnwrap(try store.load())
        XCTAssertEqual(s.version, 1)
        XCTAssertEqual(s.coins, 1234)
        XCTAssertEqual(s.upgrades.tier(of: .comb), 2)
        XCTAssertEqual(s.upgrades.tier(of: .swarm), 4)
        XCTAssertEqual(s.upgrades.tier(of: .stinger), 0)
        XCTAssertEqual(s.upgrades.tier(of: .nectar), 0)
        XCTAssertEqual(s.upgrades.tier(of: .queen), 0)
        XCTAssertEqual(s.highestClearedLevel, 3)
        XCTAssertEqual(s.recordedRunIDs, [UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!,
                                          UUID(uuidString: "0E984725-C51C-4BF4-9960-E1C80E27ABA0")!])
        XCTAssertEqual(s.bestEndlessWave, 12)
        XCTAssertEqual(s.levelsEnded, 8)
        XCTAssertEqual(s.lastInterstitialAtLevelsEnded, 6)
        XCTAssertEqual(s.lastRewardedAdAt, 1761300000.5)
        XCTAssertTrue(s.consentPrompted)
        XCTAssertEqual(s.bonusAwardedRunIDs, [UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!])
    }
}
