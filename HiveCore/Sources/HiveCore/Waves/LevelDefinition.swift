import Foundation

public enum LevelError: Error, Equatable {
    case invalid(String)
}

public struct SpawnGroup: Codable, Equatable {
    public let type: MobType
    public let count: Int
    /// Seconds between spawns in this group.
    public let interval: Double

    public init(type: MobType, count: Int, interval: Double) {
        self.type = type
        self.count = count
        self.interval = interval
    }
}

public struct WaveDefinition: Codable, Equatable {
    /// Seconds after the previous wave is cleared (or level start).
    public let delay: Double
    public let isBoss: Bool
    public let spawns: [SpawnGroup]
    /// Multiplier on the max hp of every mob spawned in this wave (and their escorts).
    public let hpScale: Double

    public init(delay: Double, isBoss: Bool = false, spawns: [SpawnGroup], hpScale: Double = 1.0) {
        self.delay = delay
        self.isBoss = isBoss
        self.spawns = spawns
        self.hpScale = hpScale
    }

    private enum CodingKeys: String, CodingKey { case delay, isBoss, spawns, hpScale }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        delay = try c.decode(Double.self, forKey: .delay)
        isBoss = try c.decodeIfPresent(Bool.self, forKey: .isBoss) ?? false
        spawns = try c.decode([SpawnGroup].self, forKey: .spawns)
        hpScale = try c.decodeIfPresent(Double.self, forKey: .hpScale) ?? 1.0
    }
}

public struct LevelDefinition: Codable, Equatable {
    public let id: Int
    public let name: String
    public let waves: [WaveDefinition]

    public init(id: Int, name: String, waves: [WaveDefinition]) {
        self.id = id
        self.name = name
        self.waves = waves
    }

    public static func load(from data: Data) throws -> LevelDefinition {
        let level = try JSONDecoder().decode(LevelDefinition.self, from: data)
        if level.waves.isEmpty {
            throw LevelError.invalid("level \(level.id) has no waves")
        }
        for (i, wave) in level.waves.enumerated() where wave.spawns.isEmpty {
            throw LevelError.invalid("level \(level.id) wave \(i) has no spawns")
        }
        for (i, wave) in level.waves.enumerated() {
            let badGroup = wave.spawns.contains { $0.count <= 0 || $0.interval < 0 }
            if badGroup || wave.delay < 0 || wave.hpScale <= 0 {
                throw LevelError.invalid("level \(level.id) wave \(i) has invalid numbers")
            }
        }
        return level
    }
}
