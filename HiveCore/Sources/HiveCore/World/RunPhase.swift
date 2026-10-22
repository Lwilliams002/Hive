import Foundation

public enum RunPhase: Equatable {
    case playing
    case pickingCards([UpgradeCard])   // Task 5
    case cleared
    case gameOver
}
