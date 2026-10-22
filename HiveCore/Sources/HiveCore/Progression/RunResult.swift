import Foundation

public struct RunResult: Equatable {
    public let runID: UUID
    public let levelId: Int
    public let cleared: Bool
    public let wavesCleared: Int
    public let totalWaves: Int
    public let coinsEarned: Int

    public init(runID: UUID, levelId: Int, cleared: Bool, wavesCleared: Int, totalWaves: Int, coinsEarned: Int) {
        self.runID = runID
        self.levelId = levelId
        self.cleared = cleared
        self.wavesCleared = wavesCleared
        self.totalWaves = totalWaves
        self.coinsEarned = coinsEarned
    }
}

public enum CoinRules {
    public static func perWave(levelId: Int) -> Int { 6 + 2 * levelId }
    public static func clearBonus(levelId: Int) -> Int { 30 + 10 * levelId }

    public static func coins(levelId: Int, wavesCleared: Int, cleared: Bool, multiplier: Double) -> Int {
        let base = wavesCleared * perWave(levelId: levelId) + (cleared ? clearBonus(levelId: levelId) : 0)
        return Int((Double(base) * multiplier).rounded())
    }
}
