import Foundation

/// Run-scoped effects from cards that change world mechanics rather than `HiveStats`.
public struct RunModifiers: Equatable {
    /// Mobs closer than this to the hive are slowed (0 = no field).
    public var slowRadius: Double = 0
    public var slowFactor: Double = 1
    public var guardBeeCount: Int = 0
    public var beeDamage: Double = 6
    /// Splash reach around a hit mob (0 = no splash).
    public var splashRadius: Double = 0
    public var splashFraction: Double = 0
    /// Fraction of hive contact damage prevented, in [0, 1).
    public var contactResist: Double = 0

    public init() {}

    /// Applies a run-modifier effect; `HiveStats` effects are ignored here.
    public mutating func apply(_ effect: CardEffect) {
        switch effect {
        case .slowField(let radius, let factor):
            slowRadius = max(slowRadius, radius)
            slowFactor *= factor
        case .addGuardBees(let n):
            guardBeeCount += n
        case .splash(let radius, let fraction):
            splashRadius = max(splashRadius, radius)
            splashFraction += fraction
        case .royalGuard:
            guardBeeCount += 3
            beeDamage *= 2
        case .contactResist(let r):
            contactResist = 1 - (1 - contactResist) * (1 - r)
        case .fireRateMultiplier, .damageMultiplier, .addProjectile, .addPierce, .addMaxHP, .healFraction:
            break
        }
    }
}
