import Foundation

public struct NectarMeter: Equatable {
    /// Thresholds crossed so far.
    public private(set) var level: Int = 0
    public private(set) var current: Int = 0

    public init() {}

    private static let thresholds = [8, 16, 28, 44, 64, 90]

    public var threshold: Int {
        level < NectarMeter.thresholds.count ? NectarMeter.thresholds[level] : 90 + 30 * (level - 5)
    }

    /// Adds nectar; returns true if a threshold was crossed (at most one per call; excess carries over).
    public mutating func add(_ amount: Int) -> Bool {
        current += amount
        if current >= threshold {
            current -= threshold
            level += 1
            return true
        }
        return false
    }
}
