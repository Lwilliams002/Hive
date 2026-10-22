import Foundation

public enum UpgradeCatalog {
    public static let milestone1: [UpgradeCard] = [
        UpgradeCard(id: "rapid_stingers", name: "Rapid Stingers", description: "+25% fire rate",
                    rarity: .common, effect: .fireRateMultiplier(1.25)),
        UpgradeCard(id: "venom", name: "Venom", description: "+30% damage",
                    rarity: .common, effect: .damageMultiplier(1.30)),
        UpgradeCard(id: "twin_stinger", name: "Twin Stinger", description: "+1 projectile",
                    rarity: .rare, effect: .addProjectile(1)),
        UpgradeCard(id: "piercing", name: "Piercing Stinger", description: "Stingers pass through 1 more mob",
                    rarity: .rare, effect: .addPierce(1)),
        UpgradeCard(id: "propolis_armor", name: "Propolis Armor", description: "+30 max HP, heal 30",
                    rarity: .common, effect: .addMaxHP(30, healBy: 30)),
        UpgradeCard(id: "royal_jelly", name: "Royal Jelly", description: "Heal 50% of max HP",
                    rarity: .common, effect: .healFraction(0.5)),
    ]

    static func weight(_ rarity: CardRarity) -> Double {
        switch rarity {
        case .common: return 70
        case .rare: return 25
        case .epic: return 5
        }
    }

    /// Draws `count` distinct cards weighted by rarity: common 70, rare 25, epic 5.
    public static func draw(count: Int, from pool: [UpgradeCard], rng: inout SeededRNG) -> [UpgradeCard] {
        var remaining = pool
        var result: [UpgradeCard] = []
        while result.count < count && !remaining.isEmpty {
            let total = remaining.reduce(0) { $0 + weight($1.rarity) }
            let target = rng.unitDouble() * total
            var acc = 0.0
            var pick = remaining.count - 1
            for (i, card) in remaining.enumerated() {
                acc += weight(card.rarity)
                if target < acc { pick = i; break }
            }
            result.append(remaining.remove(at: pick))
        }
        return result
    }
}
