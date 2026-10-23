import Foundation

public enum RunMode: Equatable, Codable {
    case story(levelId: Int)
    case endless
}

public struct RunResult: Equatable {
    public let runID: UUID
    public let levelId: Int
    public let cleared: Bool
    public let wavesCleared: Int
    public let totalWaves: Int
    public let coinsEarned: Int
    public let mode: RunMode

    public init(runID: UUID, levelId: Int, cleared: Bool, wavesCleared: Int, totalWaves: Int, coinsEarned: Int) {
        self.runID = runID
        self.levelId = levelId
        self.cleared = cleared
        self.wavesCleared = wavesCleared
        self.totalWaves = totalWaves
        self.coinsEarned = coinsEarned
        self.mode = .story(levelId: levelId)
    }

    private init(runID: UUID, endlessWavesCleared: Int, coinsEarned: Int) {
        self.runID = runID
        self.levelId = 0
        self.cleared = false
        self.wavesCleared = endlessWavesCleared
        self.totalWaves = 0
        self.coinsEarned = coinsEarned
        self.mode = .endless
    }

    public static func endless(runID: UUID, wavesCleared: Int, coinsEarned: Int) -> RunResult {
        RunResult(runID: runID, endlessWavesCleared: wavesCleared, coinsEarned: coinsEarned)
    }
}

public enum CoinRules {
    public static func perWave(levelId: Int) -> Int { 6 + 2 * levelId }
    public static func clearBonus(levelId: Int) -> Int { 30 + 10 * levelId }

    public static func coins(levelId: Int, wavesCleared: Int, cleared: Bool, multiplier: Double) -> Int {
        let base = wavesCleared * perWave(levelId: levelId) + (cleared ? clearBonus(levelId: levelId) : 0)
        return Int((Double(base) * multiplier).rounded())
    }

    public static func endlessCoins(wavesCleared n: Int, multiplier: Double) -> Int {
        guard n > 0 else { return 0 }
        let base = (1...n).reduce(0) { $0 + 12 + 6 * $1 }
        return Int((Double(base) * multiplier).rounded())
    }
}
