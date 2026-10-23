import Foundation

public enum WaveProvider: Equatable {
    case fixed(LevelDefinition)
    case endless(EndlessConfig)

    /// 0-based wave index; nil past the end of a fixed level.
    public func wave(at index: Int) -> WaveDefinition? {
        switch self {
        case .fixed(let level):
            return level.waves.indices.contains(index) ? level.waves[index] : nil
        case .endless(let config):
            return index >= 0 ? config.wave(at: index + 1) : nil
        }
    }

    /// nil when endless.
    public var count: Int? {
        switch self {
        case .fixed(let level): return level.waves.count
        case .endless: return nil
        }
    }

    public var isEndless: Bool {
        if case .endless = self { return true }
        return false
    }
}
