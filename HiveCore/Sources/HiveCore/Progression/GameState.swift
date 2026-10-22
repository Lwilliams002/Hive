import Foundation

public struct GameState: Codable, Equatable {
    public static let currentVersion = 1
    static let runIDHistoryLimit = 20

    public var version: Int
    public var coins: Int
    public var upgrades: PermanentUpgrades
    public var highestClearedLevel: Int
    public var recordedRunIDs: [UUID]

    public init() {
        self.init(version: GameState.currentVersion, coins: 0, upgrades: PermanentUpgrades(),
                  highestClearedLevel: 0, recordedRunIDs: [])
    }

    public init(version: Int, coins: Int, upgrades: PermanentUpgrades, highestClearedLevel: Int, recordedRunIDs: [UUID]) {
        self.version = version
        self.coins = coins
        self.upgrades = upgrades
        self.highestClearedLevel = highestClearedLevel
        self.recordedRunIDs = recordedRunIDs
    }

    public var currentLevel: Int { highestClearedLevel + 1 }

    public func canAfford(_ track: UpgradeTrack) -> Bool {
        guard let cost = upgrades.nextCost(for: track) else { return false }
        return coins >= cost
    }

    @discardableResult
    public mutating func purchase(_ track: UpgradeTrack) -> Bool {
        guard let cost = upgrades.nextCost(for: track), coins >= cost else { return false }
        coins -= cost
        upgrades.raise(track)
        return true
    }

    @discardableResult
    public mutating func record(_ result: RunResult) -> Bool {
        guard !recordedRunIDs.contains(result.runID) else { return false }
        coins += result.coinsEarned
        if result.cleared && result.levelId > highestClearedLevel {
            highestClearedLevel = result.levelId
        }
        recordedRunIDs.append(result.runID)
        if recordedRunIDs.count > GameState.runIDHistoryLimit {
            recordedRunIDs.removeFirst(recordedRunIDs.count - GameState.runIDHistoryLimit)
        }
        return true
    }
}
