import Foundation
import HiveCore

/// Finds and decodes the bundled `Levels/level_NNN.json` files.
final class LevelLoader {
    private let bundle: Bundle
    private var cachedIDs: [Int]?
    private var cachedNames: [Int: String] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Consecutive level ids starting at 1, stopping at the first missing file. Cached after the first call.
    func availableLevelIDs() -> [Int] {
        if let cachedIDs = cachedIDs { return cachedIDs }
        var ids: [Int] = []
        var id = 1
        while url(for: id) != nil {
            ids.append(id)
            id += 1
        }
        cachedIDs = ids
        return ids
    }

    func load(id: Int) throws -> LevelDefinition {
        guard let url = url(for: id) else { throw CocoaError(.fileNoSuchFile) }
        return try LevelDefinition.load(from: Data(contentsOf: url))
    }

    /// The level's display name; each level file is decoded at most once.
    func name(for id: Int) -> String? {
        if let name = cachedNames[id] { return name }
        guard let name = (try? load(id: id))?.name else { return nil }
        cachedNames[id] = name
        return name
    }

    private func url(for id: Int) -> URL? {
        bundle.url(forResource: String(format: "level_%03d", id), withExtension: "json", subdirectory: "Levels")
    }
}
