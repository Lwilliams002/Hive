import Foundation

public enum MobType: String, Codable, CaseIterable {
    case wasp, hornet, bear
}

public struct MobStats: Equatable {
    public let maxHP: Double
    public let speed: Double
    public let contactDamage: Double
    public let radius: Double
    public let nectar: Int
    public let isBoss: Bool

    public init(maxHP: Double, speed: Double, contactDamage: Double, radius: Double, nectar: Int, isBoss: Bool) {
        self.maxHP = maxHP
        self.speed = speed
        self.contactDamage = contactDamage
        self.radius = radius
        self.nectar = nectar
        self.isBoss = isBoss
    }
}

public extension MobType {
    var stats: MobStats {
        switch self {
        case .wasp:
            return MobStats(maxHP: 20, speed: 90, contactDamage: 10, radius: 10, nectar: 1, isBoss: false)
        case .hornet:
            return MobStats(maxHP: 60, speed: 55, contactDamage: 20, radius: 14, nectar: 3, isBoss: false)
        case .bear:
            return MobStats(maxHP: 450, speed: 28, contactDamage: 40, radius: 30, nectar: 15, isBoss: true)
        }
    }
}

public struct Mob: Identifiable, Equatable {
    public let id: Int
    public let type: MobType
    public var position: Vec2
    public var hp: Double
    /// Seconds remaining of the hit-flash rendering hint.
    public var hitFlash: Double

    public init(id: Int, type: MobType, position: Vec2) {
        self.id = id
        self.type = type
        self.position = position
        self.hp = type.stats.maxHP
        self.hitFlash = 0
    }
}
