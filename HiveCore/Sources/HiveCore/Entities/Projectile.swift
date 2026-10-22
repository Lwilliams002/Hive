import Foundation

public struct Projectile: Identifiable, Equatable {
    public let id: Int
    public var position: Vec2
    public var velocity: Vec2
    public let damage: Double
    /// Further mobs this projectile may pass through; removed once it drops below 0.
    public var pierceRemaining: Int
    /// Mobs already hit, so a projectile never hits the same mob twice.
    public var hitMobIDs: [Int]

    public static let radius: Double = 4
    public static let maxRange: Double = 700

    public init(id: Int, position: Vec2, velocity: Vec2, damage: Double, pierceRemaining: Int, hitMobIDs: [Int] = []) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.damage = damage
        self.pierceRemaining = pierceRemaining
        self.hitMobIDs = hitMobIDs
    }
}
