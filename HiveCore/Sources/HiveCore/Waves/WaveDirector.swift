import Foundation

public struct WaveDirector: Equatable {
    private let level: LevelDefinition
    private static let epsilon = 1e-9

    /// Number of waves that have been started so far.
    private var startedCount = 0
    /// True once the most recently started wave has issued every spawn.
    private var currentDone = false
    /// Time accumulated toward the next wave's delay while it is eligible.
    private var waveClock = 0.0
    /// Time since the running wave started.
    private var waveTime = 0.0
    /// Spawns issued so far per group of the running wave.
    private var issued: [Int] = []

    public init(level: LevelDefinition) {
        self.level = level
    }

    public var totalWaves: Int { level.waves.count }

    /// 0-based; == totalWaves when all waves have been issued.
    public var currentWaveIndex: Int {
        if startedCount == 0 { return 0 }
        if startedCount == totalWaves && currentDone { return totalWaves }
        return startedCount - 1
    }

    public var waveNumber: Int { min(currentWaveIndex + 1, totalWaves) }

    public var isBossWave: Bool { level.waves[waveNumber - 1].isBoss }

    public var allSpawnsIssued: Bool { startedCount == totalWaves && currentDone }

    public mutating func tick(dt: Double, aliveMobs: Int) -> [MobType] {
        if allSpawnsIssued { return [] }
        var out: [MobType] = []

        if startedCount > 0 && !currentDone {
            waveTime += dt
        } else {
            // Next wave is eligible once the previous one is fully issued and the world is clear.
            let eligible = startedCount == 0 || (currentDone && aliveMobs == 0)
            guard eligible else { return [] }
            waveClock += dt
            let wave = level.waves[startedCount]
            guard waveClock >= wave.delay - Self.epsilon else { return [] }
            waveTime = max(0, waveClock - wave.delay)
            waveClock = 0
            startedCount += 1
            currentDone = false
            issued = Array(repeating: 0, count: wave.spawns.count)
        }

        let wave = level.waves[startedCount - 1]
        for (g, group) in wave.spawns.enumerated() {
            while issued[g] < group.count,
                  Double(issued[g]) * group.interval <= waveTime + Self.epsilon {
                out.append(group.type)
                issued[g] += 1
            }
        }
        if zip(issued, wave.spawns).allSatisfy({ $0 >= $1.count }) {
            currentDone = true
        }
        return out
    }
}
