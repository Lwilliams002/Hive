import Foundation

public enum MobType: String, Codable, CaseIterable {
    case wasp, hornet, bear
    case beetle, hornetQueen, swarmMother
}

/// A boss's periodic escort: `count` mobs of `type` every `every` seconds, the first after `first` seconds.
public struct EscortSpawn: Equatable {
    public let type: MobType
    public let count: Int
    public let every: Double
    public let first: Double

    public init(type: MobType, count: Int, every: Double, first: Double) {
        self.type = type
        self.count = count
        self.every = every
        self.first = first
    }
}

public struct MobStats: Equatable {
    public let maxHP: Double
    public let speed: Double
    public let contactDamage: Double
    public let radius: Double
    public let nectar: Int
    public let isBoss: Bool
    /// Flat per-hit damage reduction; every hit still deals at least 1.
    public let armor: Double
    public let escort: EscortSpawn?

    public init(maxHP: Double, speed: Double, contactDamage: Double, radius: Double, nectar: Int, isBoss: Bool,
                armor: Double = 0, escort: EscortSpawn? = nil) {
        self.maxHP = maxHP
        self.speed = speed
        self.contactDamage = contactDamage
        self.radius = radius
        self.nectar = nectar
        self.isBoss = isBoss
        self.armor = armor
        self.escort = escort
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
        case .beetle:
            return MobStats(maxHP: 90, speed: 40, contactDamage: 25, radius: 13, nectar: 4, isBoss: false, armor: 5)
        case .hornetQueen:
            return MobStats(maxHP: 700, speed: 32, contactDamage: 35, radius: 26, nectar: 20, isBoss: true,
                            escort: EscortSpawn(type: .hornet, count: 2, every: 6, first: 3))
        case .swarmMother:
            return MobStats(maxHP: 380, speed: 45, contactDamage: 25, radius: 22, nectar: 18, isBoss: true,
                            escort: EscortSpawn(type: .wasp, count: 4, every: 4, first: 2))
        }
    }
}

public struct Mob: Identifiable, Equatable {
    public let id: Int
    public let type: MobType
    public var position: Vec2
    public var hp: Double
    /// `type.stats.maxHP · hpScale`, fixed at spawn (for HUD/visual scaling).
    public var maxHP: Double
    /// The spawning wave's hp multiplier; escorts inherit their parent's.
    public let hpScale: Double
    /// Seconds remaining of the hit-flash rendering hint.
    public var hitFlash: Double
    /// Seconds until a boss parked at the hive edge hits again; 0 means it hits on arrival.
    public var attackCooldown: Double
    /// Seconds until this mob's next escort spawn; unused for mobs without `escort`.
    public var escortTimer: Double

    public init(id: Int, type: MobType, position: Vec2) {
        self.init(id: id, type: type, position: position, hpScale: 1)
    }

    public init(id: Int, type: MobType, position: Vec2, hpScale: Double) {
        let stats = type.stats
        self.id = id
        self.type = type
        self.position = position
        self.hpScale = hpScale
        self.maxHP = stats.maxHP * hpScale
        self.hp = self.maxHP
        self.hitFlash = 0
        self.attackCooldown = 0
        self.escortTimer = stats.escort?.first ?? 0
    }
}
