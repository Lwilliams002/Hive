import Foundation

public enum GameEvent: Equatable {
    case mobSpawned(id: Int, type: MobType)
    /// A boss spawned escorts `ids` (each also reported via `mobSpawned`).
    case escortSpawned(parentID: Int, ids: [Int])
    case projectileFired(id: Int)
    case mobHit(id: Int)
    case mobKilled(id: Int, type: MobType, at: Vec2)
    case hiveDamaged(amount: Double, hp: Double)
    case waveStarted(number: Int, isBoss: Bool)
    case nectarThreshold          // Task 5 fills in the card draw
    case levelCleared
    case gameOver
}
