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
    // M4 (R14, R16): run-end counters, ad timing and the double-coins ledger. Every field is additive and
    // defaulted, so `currentVersion` stays 1 and pre-M4 saves decode with the fresh-install values.
    /// Newly recorded run ends of any kind (story clear or loss, endless end, pause-abandon); +1 per `record`.
    public var levelsEnded: Int
    /// `levelsEnded` at the moment the last interstitial was shown (`AdRules.noteInterstitialShown`).
    public var lastInterstitialAtLevelsEnded: Int
    /// Unix seconds of the last rewarded ad shown (`AdRules.noteRewardedShown`); nil until one has been.
    public var lastRewardedAdAt: Double?
    /// Whether the consent flow (UMP → ATT) has been triggered once; set at the trigger, not on completion.
    public var consentPrompted: Bool
    /// Run ids whose double-coins bonus has been paid; 20 most recent, like `recordedRunIDs`.
    public var bonusAwardedRunIDs: [UUID]

    public init() {
        self.init(version: GameState.currentVersion, coins: 0, upgrades: PermanentUpgrades(),
                  highestClearedLevel: 0, recordedRunIDs: [], bestEndlessWave: 0,
                  levelsEnded: 0, lastInterstitialAtLevelsEnded: 0, lastRewardedAdAt: nil,
                  consentPrompted: false, bonusAwardedRunIDs: [])
    }

    public init(version: Int, coins: Int, upgrades: PermanentUpgrades, highestClearedLevel: Int, recordedRunIDs: [UUID],
                bestEndlessWave: Int = 0, levelsEnded: Int = 0, lastInterstitialAtLevelsEnded: Int = 0,
                lastRewardedAdAt: Double? = nil, consentPrompted: Bool = false, bonusAwardedRunIDs: [UUID] = []) {
        self.version = version
        self.coins = coins
        self.upgrades = upgrades
        self.highestClearedLevel = highestClearedLevel
        self.recordedRunIDs = recordedRunIDs
        self.bestEndlessWave = bestEndlessWave
        self.levelsEnded = levelsEnded
        self.lastInterstitialAtLevelsEnded = lastInterstitialAtLevelsEnded
        self.lastRewardedAdAt = lastRewardedAdAt
        self.consentPrompted = consentPrompted
        self.bonusAwardedRunIDs = bonusAwardedRunIDs
    }

    private enum CodingKeys: String, CodingKey {
        case version, coins, upgrades, highestClearedLevel, recordedRunIDs, bestEndlessWave
        case levelsEnded, lastInterstitialAtLevelsEnded, lastRewardedAdAt, consentPrompted, bonusAwardedRunIDs
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
                  bestEndlessWave: try c.decodeIfPresent(Int.self, forKey: .bestEndlessWave) ?? 0,
                  levelsEnded: try c.decodeIfPresent(Int.self, forKey: .levelsEnded) ?? 0,
                  lastInterstitialAtLevelsEnded: try c.decodeIfPresent(Int.self, forKey: .lastInterstitialAtLevelsEnded) ?? 0,
                  lastRewardedAdAt: try c.decodeIfPresent(Double.self, forKey: .lastRewardedAdAt),
                  consentPrompted: try c.decodeIfPresent(Bool.self, forKey: .consentPrompted) ?? false,
                  bonusAwardedRunIDs: try c.decodeIfPresent([UUID].self, forKey: .bonusAwardedRunIDs) ?? [])
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
        levelsEnded += 1
        if recordedRunIDs.count > GameState.runIDHistoryLimit {
            recordedRunIDs.removeFirst(recordedRunIDs.count - GameState.runIDHistoryLimit)
        }
        return true
    }

    /// Pays the double-coins bonus for a recorded run, once (M4 R20). `bonus` is `result.coinsEarned`, already
    /// multiplied once by `makeRunResult`; it is never re-multiplied here. Keeps its own ledger so
    /// `recordedRunIDs` stays the `record` idempotency list untouched.
    @discardableResult
    public mutating func awardBonus(runID: UUID, coins bonus: Int) -> Bool {
        guard bonus > 0, recordedRunIDs.contains(runID), !bonusAwardedRunIDs.contains(runID) else { return false }
        coins += bonus
        bonusAwardedRunIDs.append(runID)
        if bonusAwardedRunIDs.count > GameState.runIDHistoryLimit {
            bonusAwardedRunIDs.removeFirst(bonusAwardedRunIDs.count - GameState.runIDHistoryLimit)
        }
        return true
    }
}
