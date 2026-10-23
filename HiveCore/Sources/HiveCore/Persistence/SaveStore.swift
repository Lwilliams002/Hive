import Foundation

public enum SaveError: Error {
    case corrupt(backupPath: String)
    case io(Error)
}

public protocol SaveStore {
    func load() throws -> GameState?
    func save(_ state: GameState) throws
}

public final class InMemorySaveStore: SaveStore {
    public var stored: GameState?
    public init() {}
    public func load() throws -> GameState? { stored }
    public func save(_ state: GameState) throws { stored = state }
}

public final class FileSaveStore: SaveStore {
    private struct VersionProbe: Decodable { let version: Int? }

    private let directory: URL
    private let fileName: String

    public init(directory: URL, fileName: String = "save.json") {
        self.directory = directory
        self.fileName = fileName
    }

    public var fileURL: URL { directory.appendingPathComponent(fileName) }

    public func load() throws -> GameState? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do { data = try Data(contentsOf: fileURL) } catch { throw SaveError.io(error) }

        let decoder = JSONDecoder()
        // A missing version means v1 (matches GameState's decode default); < 1 or newer than this build is corrupt.
        if let probe = try? decoder.decode(VersionProbe.self, from: data),
           (1...GameState.currentVersion).contains(probe.version ?? 1),
           let state = try? decoder.decode(GameState.self, from: data) {
            return state
        }
        throw SaveError.corrupt(backupPath: try quarantine())
    }

    public func save(_ state: GameState) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(state).write(to: fileURL, options: .atomic)
        } catch {
            throw SaveError.io(error)
        }
    }

    private func quarantine() throws -> String {
        let fm = FileManager.default
        let base = "\(fileName).corrupt-\(Int(Date().timeIntervalSince1970))"
        var target = directory.appendingPathComponent(base)
        var n = 1
        while fm.fileExists(atPath: target.path) {
            target = directory.appendingPathComponent("\(base)-\(n)")
            n += 1
        }
        do { try fm.moveItem(at: fileURL, to: target) } catch { throw SaveError.io(error) }
        return target.path
    }
}
