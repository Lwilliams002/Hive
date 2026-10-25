import Foundation

public enum RunPhase: Equatable {
    case playing
    case pickingCards([UpgradeCard])   // Task 5
    /// The hive fell while a revive was permitted and unused (M4): `tick` is a no-op until `revive()` resumes
    /// play or `abandonRevive()` enters `.gameOver`.
    case downed
    case cleared
    case gameOver
}
