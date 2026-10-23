import Foundation

/// Generator for the endless mode: wave `n` (1-based) is a pure function of `n`.
public struct EndlessConfig: Equatable {
    public init() {}

    private static let bosses: [MobType] = [.bear, .hornetQueen, .swarmMother]

    public func wave(at n: Int) -> WaveDefinition {
        var spawns = [SpawnGroup(type: .wasp, count: 8 + 2 * n, interval: max(0.25, 0.8 - 0.015 * Double(n)))]
        if n >= 2 { spawns.append(SpawnGroup(type: .hornet, count: n / 2, interval: 2.0)) }
        if n >= 4 { spawns.append(SpawnGroup(type: .beetle, count: n / 3, interval: 2.5)) }
        let isBoss = n % 5 == 0
        if isBoss {
            spawns.append(SpawnGroup(type: EndlessConfig.bosses[(n / 5 - 1) % EndlessConfig.bosses.count],
                                     count: 1, interval: 0))
        }
        return WaveDefinition(delay: 2.0, isBoss: isBoss, spawns: spawns, hpScale: 1 + 0.06 * Double(n))
    }
}
