import Foundation

public enum CardRarity: String, Codable {
    case common, rare, epic
}

public enum CardEffect: Equatable {
    case fireRateMultiplier(Double)
    case damageMultiplier(Double)
    case addProjectile(Int)
    case addPierce(Int)
    case addMaxHP(Double, healBy: Double)
    case healFraction(Double)
}

extension CardEffect {
    /// Effects that only add or restore HP. At run start the hive is at full health, so these are
    /// excluded from starting-card draws (a heal would be wasted).
    public var isHealOnly: Bool {
        switch self {
        case .healFraction, .addMaxHP: return true
        case .fireRateMultiplier, .damageMultiplier, .addProjectile, .addPierce: return false
        }
    }
}

public struct UpgradeCard: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let rarity: CardRarity
    public let effect: CardEffect

    public init(id: String, name: String, description: String, rarity: CardRarity, effect: CardEffect) {
        self.id = id
        self.name = name
        self.description = description
        self.rarity = rarity
        self.effect = effect
    }
}

extension HiveStats {
    /// Applies a card effect to these stats and, where relevant, the hive's current hp.
    public mutating func apply(_ effect: CardEffect, to hive: inout Hive) {
        switch effect {
        case .fireRateMultiplier(let m):
            fireRate *= m
        case .damageMultiplier(let m):
            damage *= m
        case .addProjectile(let n):
            projectileCount += n
        case .addPierce(let n):
            pierce += n
        case .addMaxHP(let amount, let healBy):
            maxHP += amount
            hive.hp = min(hive.hp + healBy, maxHP)
        case .healFraction(let f):
            hive.hp = min(hive.hp + f * maxHP, maxHP)
        }
    }
}
