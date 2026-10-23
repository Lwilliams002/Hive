import Foundation

public struct PermanentUpgrades: Codable, Equatable {
    public static let maxTier = 10

    private var tiers: [UpgradeTrack: Int]

    public init() {
        tiers = [:]
    }

    public init(tiers: [UpgradeTrack: Int]) {
        var clamped: [UpgradeTrack: Int] = [:]
        for (track, t) in tiers {
            let v = min(max(t, 0), PermanentUpgrades.maxTier)
            if v > 0 { clamped[track] = v }  // normalize: zero tiers are never stored
        }
        self.tiers = clamped
    }

    private enum CodingKeys: String, CodingKey { case tiers }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decodeIfPresent([String: Int].self, forKey: .tiers) ?? [:]
        var parsed: [UpgradeTrack: Int] = [:]
        for (key, value) in raw {
            if let track = UpgradeTrack(rawValue: key) { parsed[track] = value }
        }
        self.init(tiers: parsed)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        var raw: [String: Int] = [:]
        for track in UpgradeTrack.allCases { raw[track.rawValue] = tier(of: track) }
        try c.encode(raw, forKey: .tiers)
    }

    public func tier(of track: UpgradeTrack) -> Int { tiers[track] ?? 0 }

    public var totalTiers: Int { UpgradeTrack.allCases.reduce(0) { $0 + tier(of: $1) } }

    /// Permanent tiers bought per visual-tier step of the hive.
    public static let tiersPerLook = 5

    public var visualTier: Int { 1 + totalTiers / PermanentUpgrades.tiersPerLook }

    /// Tiers still to buy before the hive's look changes; 0 once the final look (visual tier 11) is reached.
    public var tiersToNextLook: Int {
        let lastLook = 1 + UpgradeTrack.allCases.count * PermanentUpgrades.maxTier / PermanentUpgrades.tiersPerLook
        guard visualTier < lastLook else { return 0 }
        return PermanentUpgrades.tiersPerLook - totalTiers % PermanentUpgrades.tiersPerLook
    }

    public static func cost(forTier t: Int) -> Int { 20 + 30 * t * t }

    /// Highest cleared level needed before tier `t` can be bought.
    public static func unlockLevel(forTier t: Int) -> Int {
        t >= 9 ? 16 : (t >= 6 ? 8 : 0)
    }

    public func nextCost(for track: UpgradeTrack) -> Int? {
        let t = tier(of: track)
        return t >= PermanentUpgrades.maxTier ? nil : PermanentUpgrades.cost(forTier: t + 1)
    }

    public mutating func raise(_ track: UpgradeTrack) {
        let t = tier(of: track)
        guard t < PermanentUpgrades.maxTier else { return }
        tiers[track] = t + 1
    }

    // MARK: Derivation

    private static func maxHP(atTier t: Int) -> Double { 100 + 15 * Double(t) }
    private static func damage(atTier t: Int) -> Double { 10 + 1.5 * Double(t) }
    private static func fireRate(atTier t: Int) -> Double { 2 + 0.15 * Double(t) }
    private static func projectileCount(atTier t: Int) -> Int { 1 + (t >= 4 ? 1 : 0) + (t >= 8 ? 1 : 0) }
    private static func coinMultiplier(atTier t: Int) -> Double { 1 + 0.10 * Double(t) }
    private static func startingCards(atTier t: Int) -> Int { t / 3 }

    public func hiveStats() -> HiveStats {
        var s = HiveStats.base
        s.maxHP = Self.maxHP(atTier: tier(of: .comb))
        s.damage = Self.damage(atTier: tier(of: .stinger))
        s.fireRate = Self.fireRate(atTier: tier(of: .swarm))
        s.projectileCount = Self.projectileCount(atTier: tier(of: .swarm))
        return s
    }

    public var coinMultiplier: Double { Self.coinMultiplier(atTier: tier(of: .nectar)) }

    public var startingCardCount: Int { Self.startingCards(atTier: tier(of: .queen)) }

    public func effectDescription(for track: UpgradeTrack, atTier t: Int) -> String {
        let t = min(max(t, 0), PermanentUpgrades.maxTier)
        switch track {
        case .comb:
            return "HP \(Self.format(Self.maxHP(atTier: t)))"
        case .stinger:
            return "Damage \(Self.format(Self.damage(atTier: t)))"
        case .swarm:
            let n = Self.projectileCount(atTier: t)
            return "Fire rate \(Self.format(Self.fireRate(atTier: t)))/s · \(n) \(n == 1 ? "stinger" : "stingers")"
        case .nectar:
            return "+\(Int((Double(t) * 10).rounded()))% coins"
        case .queen:
            let n = Self.startingCards(atTier: t)
            switch n {
            case 0: return "No starting cards"
            case 1: return "1 starting card"
            default: return "\(n) starting cards"
            }
        }
    }

    /// Up to one decimal, dropping a trailing ".0".
    private static func format(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }
}
