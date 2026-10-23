import Foundation

/// The designed progression curve: how many permanent tiers a player is expected to own when
/// starting a story level, and the loadout the balance probes use for a given tier total.
public enum ExpectedProgress {
    /// Combat tracks in the order the probe loadout fills them. Nectar is excluded (it is not combat).
    public static let probeTracks: [UpgradeTrack] = [.stinger, .swarm, .comb, .queen]

    /// Total permanent tiers expected at the start of level `level`:
    /// `min(50, Int((L − 1) · 1.2))` (L1 0, L5 4, L10 10, L20 22, L30 34).
    public static func totalTiers(forLevel level: Int) -> Int {
        min(50, max(0, Int(Double(level - 1) * 1.2)))
    }

    /// Round-robin stinger → swarm → comb → queen, one tier at a time, each capped at
    /// `PermanentUpgrades.maxTier`. Tiers beyond 40 (all four combat tracks maxed) are dropped,
    /// since nectar is never assigned.
    public static func probeLoadout(totalTiers: Int) -> PermanentUpgrades {
        var tiers: [UpgradeTrack: Int] = [:]
        var remaining = max(0, totalTiers)
        var i = 0
        let cap = PermanentUpgrades.maxTier * probeTracks.count
        while remaining > 0 && i < cap {
            let track = probeTracks[i % probeTracks.count]
            tiers[track, default: 0] += 1
            remaining -= 1
            i += 1
        }
        return PermanentUpgrades(tiers: tiers)
    }
}
