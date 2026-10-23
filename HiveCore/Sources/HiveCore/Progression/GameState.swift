import Foundation

public struct GameState: Codable, Equatable {
    public static let currentVersion = 1
    static let runIDHistoryLimit = 20

    public var version: Int
    public var coins: Int
    public var upgrades: PermanentUpgrades
    public var highestClearedLevel: Int
    public var recordedRunIDs: [UUID]
    public var bestEndlessWave: Int

    public init() {
        self.init(version: GameState.currentVersion, coins: 0, upgrades: PermanentUpgrades(),
                  highestClearedLevel: 0, recordedRunIDs: [], bestEndlessWave: 0)
    }

    public init(version: Int, coins: Int, upgrades: PermanentUpgrades, highestClearedLevel: Int, recordedRunIDs: [UUID],
                bestEndlessWave: Int = 0) {
        self.version = version
        self.coins = coins
        self.upgrades = upgrades
        self.highestClearedLevel = highestClearedLevel
        self.recordedRunIDs = recordedRunIDs
        self.bestEndlessWave = bestEndlessWave
    }

    private enum CodingKeys: String, CodingKey {
        case version, coins, upgrades, highestClearedLevel, recordedRunIDs, bestEndlessWave
    }

    /// Tolerant decode: every field is optional with a default, so saves written before a field
    /// existed (or by a future build that dropped one) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(version: try c.decodeIfPresent(Int.self, forKey: .version) ?? 1,
                  coins: try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0,
                  upgrades: try c.decodeIfPresent(PermanentUpgrades.self, forKey: .upgrades) ?? PermanentUpgrades(),
                  highestClearedLevel: try c.decodeIfPresent(Int.self, forKey: .highestClearedLevel) ?? 0,
                  recordedRunIDs: try c.decodeIfPresent([UUID].self, forKey: .recordedRunIDs) ?? [],
                  bestEndlessWave: try c.decodeIfPresent(Int.self, forKey: .bestEndlessWave) ?? 0)
    }

    public var currentLevel: Int { highestClearedLevel + 1 }

    public func canAfford(_ track: UpgradeTrack) -> Bool {
        guard let cost = upgrades.nextCost(for: track) else { return false }
        return coins >= cost
    }

    public var endlessUnlocked: Bool { highestClearedLevel >= 10 }

    public enum PurchaseBlock: Equatable {
        case maxed, lockedUntil(level: Int), cannotAfford
    }

    /// Why the next tier of `track` cannot be bought; nil means it can.
    public func purchaseBlock(for track: UpgradeTrack) -> PurchaseBlock? {
        guard let cost = upgrades.nextCost(for: track) else { return .maxed }
        let required = PermanentUpgrades.unlockLevel(forTier: upgrades.tier(of: track) + 1)
        if highestClearedLevel < required { return .lockedUntil(level: required) }
        if coins < cost { return .cannotAfford }
        return nil
    }

    @discardableResult
    public mutating func purchase(_ track: UpgradeTrack) -> Bool {
        guard purchaseBlock(for: track) == nil, let cost = upgrades.nextCost(for: track) else { return false }
        coins -= cost
        upgrades.raise(track)
        return true
    }

    @discardableResult
    public mutating func record(_ result: RunResult) -> Bool {
        guard !recordedRunIDs.contains(result.runID) else { return false }
        coins += result.coinsEarned
        switch result.mode {
        case .story:
            if result.cleared && result.levelId > highestClearedLevel {
                highestClearedLevel = result.levelId
            }
        case .endless:
            bestEndlessWave = max(bestEndlessWave, result.wavesCleared)
        }
        recordedRunIDs.append(result.runID)
        if recordedRunIDs.count > GameState.runIDHistoryLimit {
            recordedRunIDs.removeFirst(recordedRunIDs.count - GameState.runIDHistoryLimit)
        }
        return true
    }
}
