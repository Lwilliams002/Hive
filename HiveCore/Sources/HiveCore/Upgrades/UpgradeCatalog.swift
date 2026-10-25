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

    /// Every card: the six `milestone1` cards followed by the milestone 3 additions.
    public static let all: [UpgradeCard] = milestone1 + [
        UpgradeCard(id: "honey_field", name: "Honey Field", description: "Mobs within 160 of the hive move 35% slower",
                    rarity: .rare, effect: .slowField(radius: 160, factor: 0.65)),
        UpgradeCard(id: "guard_bees", name: "Guard Bees", description: "+2 bees orbit the hive, 6 damage on touch",
                    rarity: .rare, effect: .addGuardBees(2)),
        UpgradeCard(id: "pollen_cloud", name: "Pollen Cloud", description: "Hits spread 40% damage to mobs within 45",
                    rarity: .rare, effect: .splash(radius: 45, fraction: 0.4)),
        UpgradeCard(id: "queens_wrath", name: "Queen's Wrath", description: "+60% damage",
                    rarity: .epic, effect: .damageMultiplier(1.6), unlockLevel: 5),
        UpgradeCard(id: "swarm_call", name: "Swarm Call", description: "+2 projectiles",
                    rarity: .epic, effect: .addProjectile(2), unlockLevel: 10),
        UpgradeCard(id: "royal_guard", name: "Royal Guard", description: "+3 bees, bee damage doubled",
                    rarity: .epic, effect: .royalGuard, unlockLevel: 15),
        UpgradeCard(id: "thick_wax", name: "Thick Wax", description: "Hive takes 30% less contact damage",
                    rarity: .epic, effect: .contactResist(0.3), unlockLevel: 7),
    ]

    /// Cards available once `level` has been cleared (`unlockLevel <= level`).
    public static func pool(unlockedThrough level: Int) -> [UpgradeCard] {
        all.filter { $0.unlockLevel <= level }
    }

    /// The premium slot's pool: the cards still locked at `level` (`unlockLevel > level`), the exact complement of
    /// `pool(unlockedThrough:)`. Story level 1 (`poolLevel` 0) offers the four epics; empty from level 15, which
    /// hides the slot (R8, R9).
    public static func locked(unlockedThrough level: Int) -> [UpgradeCard] {
        all.filter { $0.unlockLevel > level }
    }

    static func weight(_ rarity: CardRarity, epicWeight: Double) -> Double {
        switch rarity {
        case .common: return 70
        case .rare: return 25
        case .epic: return epicWeight
        }
    }

    /// Draws `count` distinct cards weighted by rarity: common 70, rare 25, epic `epicWeight` (default 5).
    public static func draw(count: Int, from pool: [UpgradeCard], rng: inout SeededRNG,
                            epicWeight: Int = 5) -> [UpgradeCard] {
        let epic = Double(epicWeight)
        var remaining = pool
        var result: [UpgradeCard] = []
        while result.count < count && !remaining.isEmpty {
            let total = remaining.reduce(0) { $0 + weight($1.rarity, epicWeight: epic) }
            let target = rng.unitDouble() * total
            var acc = 0.0
            var pick = remaining.count - 1
            for (i, card) in remaining.enumerated() {
                acc += weight(card.rarity, epicWeight: epic)
                if target < acc { pick = i; break }
            }
            result.append(remaining.remove(at: pick))
        }
        return result
    }
}
