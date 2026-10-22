import Foundation

public enum UpgradeTrack: String, Codable, CaseIterable, Equatable {
    case comb, stinger, swarm, nectar, queen

    public var displayName: String {
        switch self {
        case .comb: return "Comb"
        case .stinger: return "Stinger"
        case .swarm: return "Swarm"
        case .nectar: return "Nectar"
        case .queen: return "Queen"
        }
    }

    public var summary: String {
        switch self {
        case .comb: return "Hive HP"
        case .stinger: return "Damage"
        case .swarm: return "Fire rate & stingers"
        case .nectar: return "Coins per run"
        case .queen: return "Starting cards"
        }
    }
}
