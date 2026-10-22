import Foundation

public struct HiveStats: Equatable {
    public var maxHP: Double
    public var damage: Double
    /// Shots per second.
    public var fireRate: Double
    public var projectileCount: Int
    /// Extra mobs a stinger passes through.
    public var pierce: Int
    public var projectileSpeed: Double

    public init(maxHP: Double = 100, damage: Double = 10, fireRate: Double = 2,
                projectileCount: Int = 1, pierce: Int = 0, projectileSpeed: Double = 420) {
        self.maxHP = maxHP
        self.damage = damage
        self.fireRate = fireRate
        self.projectileCount = projectileCount
        self.pierce = pierce
        self.projectileSpeed = projectileSpeed
    }

    public static let base = HiveStats()
}

public struct Hive: Equatable {
    public var stats: HiveStats
    public var hp: Double
    /// Seconds until the next volley may fire.
    public var cooldown: Double

    public static let radius: Double = 40

    public init(stats: HiveStats, hp: Double, cooldown: Double) {
        self.stats = stats
        self.hp = hp
        self.cooldown = cooldown
    }
}
