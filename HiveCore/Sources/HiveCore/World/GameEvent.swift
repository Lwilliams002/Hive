import Foundation

public enum GameEvent: Equatable {
    case mobSpawned(id: Int, type: MobType)
    /// A boss spawned escorts `ids` (each also reported via `mobSpawned`).
    case escortSpawned(parentID: Int, ids: [Int])
    case projectileFired(id: Int)
    case mobHit(id: Int)
    /// A guard bee stung mob `mobID`.
    case beeHit(mobID: Int)
    case mobKilled(id: Int, type: MobType, at: Vec2)
    case hiveDamaged(amount: Double, hp: Double)
    /// The hive fell with a revive permitted and unused: the run entered `.downed` (M4). `.gameOver` follows
    /// only if the revive is declined or a revived hive falls again.
    case hiveDowned
    case waveStarted(number: Int, isBoss: Bool)
    case nectarThreshold          // Task 5 fills in the card draw
    case levelCleared
    case gameOver
}
