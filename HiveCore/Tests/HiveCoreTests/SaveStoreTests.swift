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
}
