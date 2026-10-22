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

    public init(delay: Double, isBoss: Bool = false, spawns: [SpawnGroup]) {
        self.delay = delay
        self.isBoss = isBoss
        self.spawns = spawns
    }

    private enum CodingKeys: String, CodingKey { case delay, isBoss, spawns }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        delay = try c.decode(Double.self, forKey: .delay)
        isBoss = try c.decodeIfPresent(Bool.self, forKey: .isBoss) ?? false
        spawns = try c.decode([SpawnGroup].self, forKey: .spawns)
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
        return level
    }
}
