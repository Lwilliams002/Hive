import Foundation

/// A bee orbiting the hive. Its position is derived from world time and its index (see `World.beePositions`).
public struct GuardBee: Identifiable, Equatable {
    public let id: Int
    /// Seconds until this bee may hit each mob (by mob id) again.
    public var cooldowns: [Int: Double]

    public init(id: Int, cooldowns: [Int: Double] = [:]) {
        self.id = id
        self.cooldowns = cooldowns
    }

    public static let orbitRadius: Double = 72
    /// Radians per second.
    public static let angularSpeed: Double = 2.4
    /// A bee touches a mob when closer than `mob radius + touchRadius`.
    public static let touchRadius: Double = 6
    /// Seconds between one bee's hits on the same mob.
    public static let hitCooldown: Double = 0.5
}
