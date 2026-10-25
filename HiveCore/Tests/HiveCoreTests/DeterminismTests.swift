import XCTest
import Foundation
@testable import HiveCore

/// Pins World's main-RNG stream (R29/R30): two golden runs with literal event counts and a digest of the
/// event stream, plus a same-seed determinism check. The literals were recorded in the Linux container on
/// 2026-10-24 at 130e8d2, before the World split, with exactly the `line` format below. A diff is a stop,
/// never a re-tune.
final class DeterminismTests: XCTestCase {
    struct Summary {
        var spawned = 0, fired = 0, hit = 0, killed = 0, hiveDamaged = 0, waves = 0, thresholds = 0,
            cleared = 0, gameOver = 0, escorts = 0, beeHits = 0, other = 0
        var lines: [String] = []
        var events: Int { lines.count }

        mutating func add(_ e: GameEvent) {
            switch e {
            case .mobSpawned: spawned += 1
            case .escortSpawned: escorts += 1
            case .projectileFired: fired += 1
            case .mobHit: hit += 1
            case .beeHit: beeHits += 1
            case .mobKilled: killed += 1
            case .hiveDamaged: hiveDamaged += 1
            case .waveStarted: waves += 1
            case .nectarThreshold: thresholds += 1
            case .levelCleared: cleared += 1
            case .gameOver: gameOver += 1
            // Deliberate: warns "will never be executed" until Task 3 adds `.hiveDowned`, so this file never needs editing.
            default: other += 1
            }
            lines.append(DeterminismTests.line(e))
        }

        var sha: String { PortableSHA256.hexDigest(Data(lines.joined(separator: "\n").utf8)) }
    }

    static func f(_ x: Double) -> String { String(format: "%.6f", x) }

    /// Platform-stable text for an event — not `"\(e)"` (reflection output and libm ulps differ across toolchains).
    static func line(_ e: GameEvent) -> String {
        switch e {
        case .mobSpawned(let id, let type): return "spawned \(id) \(type.rawValue)"
        case .escortSpawned(let parentID, let ids): return "escort \(parentID) \(ids.map(String.init).joined(separator: ","))"
        case .projectileFired(let id): return "fired \(id)"
        case .mobHit(let id): return "hit \(id)"
        case .beeHit(let mobID): return "bee \(mobID)"
        case .mobKilled(let id, let type, let at): return "killed \(id) \(type.rawValue) \(f(at.x)) \(f(at.y))"
        case .hiveDamaged(let amount, let hp): return "hiveDamaged \(f(amount)) \(f(hp))"
        case .waveStarted(let number, let isBoss): return "wave \(number) \(isBoss)"
        case .nectarThreshold: return "threshold"
        case .levelCleared: return "cleared"
        case .gameOver: return "gameOver"
        default: return "other"
        }
    }

    static func phaseName(_ p: RunPhase) -> String {
        switch p {
        case .playing: return "playing"
        case .pickingCards: return "picking"
        case .cleared: return "cleared"
        case .gameOver: return "gameOver"
        default: return "other"
        }
    }

    /// Ticks `world` for `ticks` frames of 1/30 s, resolving any pick with `cards[0]`, and always prints one
    /// `GoldenRun[tag]` line — the recording aid for the literals below.
    @discardableResult
    static func golden(_ tag: String, _ world: inout World, ticks: Int) -> Summary {
        var s = Summary()
        for _ in 0..<ticks {
            for e in world.tick(dt: 1.0 / 30) { s.add(e) }
            if case .pickingCards(let cards) = world.phase { world.choose(cards[0]) }
        }
        print("GoldenRun[\(tag)]: events=\(s.events) spawned=\(s.spawned) fired=\(s.fired) hit=\(s.hit) killed=\(s.killed) "
              + "hiveDamaged=\(s.hiveDamaged) waves=\(s.waves) thresholds=\(s.thresholds) cleared=\(s.cleared) "
              + "gameOver=\(s.gameOver) escorts=\(s.escorts) beeHits=\(s.beeHits) other=\(s.other) "
              + "hp=\(f(world.hive.hp)) time=\(f(world.time)) mobs=\(world.mobs.count) projectiles=\(world.projectiles.count) "
              + "nectar=\(world.nectar.level)/\(world.nectar.current) bees=\(world.bees.count) "
              + "wavesCleared=\(world.wavesCleared) phase=\(phaseName(world.phase)) sha256=\(s.sha)")
        return s
    }

    /// 12 wasps, then a hornet queen (escorts) with 4 beetles (armor): exercises escort jitter, the card draw,
    /// splash, bees and armor in one run.
    static let mechanicsJSON = #"{"id":98,"name":"g","waves":[{"delay":0,"spawns":[{"type":"wasp","count":12,"interval":0.3}]},{"delay":1.0,"isBoss":true,"spawns":[{"type":"hornetQueen","count":1,"interval":0},{"type":"beetle","count":4,"interval":1.5}]}]}"#
    static func mechanicsLevel() -> LevelDefinition { try! LevelDefinition.load(from: Data(mechanicsJSON.utf8)) }
    static let mechanicsHive = HiveStats(maxHP: 100000, damage: 12, fireRate: 3, projectileCount: 2)
    static func card(_ id: String) -> UpgradeCard { UpgradeCatalog.all.first { $0.id == id }! }

    // Recorded 2026-10-24 at 130e8d2 (Linux container):
    // GoldenRun[A]: events=78 spawned=6 fired=35 hit=30 killed=5 hiveDamaged=0 waves=2 thresholds=0 cleared=0 gameOver=0
    //   escorts=0 beeHits=0 other=0 hp=100.000000 time=20.000000 mobs=1 projectiles=0 nectar=0/5 bees=0 wavesCleared=1
    //   phase=playing sha256=531b22b7e5535238430a04c5529301dd445cfecf4b03f5bf7b6cd4dfe1b23062
    func testGoldenRunUnchanged() throws {
        let url = Bundle.module.url(forResource: "level_test", withExtension: "json", subdirectory: "Fixtures")!
        let level = try LevelDefinition.load(from: Data(contentsOf: url))
        var w = World(level: level, seed: 7)
        let s = Self.golden("A", &w, ticks: 600)
        XCTAssertEqual(s.events, 78)
        XCTAssertEqual(s.spawned, 6)
        XCTAssertEqual(s.fired, 35)
        XCTAssertEqual(s.hit, 30)
        XCTAssertEqual(s.killed, 5)
        XCTAssertEqual(s.hiveDamaged, 0)
        XCTAssertEqual(s.waves, 2)
        XCTAssertEqual(s.thresholds, 0)
        XCTAssertEqual(s.cleared, 0)
        XCTAssertEqual(s.gameOver, 0)
        XCTAssertEqual(s.escorts, 0)
        XCTAssertEqual(s.beeHits, 0)
        XCTAssertEqual(s.other, 0)
        XCTAssertEqual(w.hive.hp, 100, accuracy: 1e-9)
        XCTAssertEqual(w.time, 20, accuracy: 1e-9)
        XCTAssertEqual(w.mobs.count, 1)
        XCTAssertEqual(w.projectiles.count, 0)
        XCTAssertEqual(w.nectar.level, 0)
        XCTAssertEqual(w.nectar.current, 5)
        XCTAssertEqual(w.bees.count, 0)
        XCTAssertEqual(w.wavesCleared, 1)
        XCTAssertEqual(w.phase, .playing)
        XCTAssertEqual(s.sha, "531b22b7e5535238430a04c5529301dd445cfecf4b03f5bf7b6cd4dfe1b23062")
    }

    // Recorded 2026-10-24 at 130e8d2 (Linux container):
    // GoldenRun[B]: events=212 spawned=21 fired=116 hit=55 killed=14 hiveDamaged=0 waves=2 thresholds=1 cleared=0 gameOver=0
    //   escorts=2 beeHits=1 other=0 hp=100000.000000 time=20.000000 mobs=7 projectiles=2 nectar=1/10 bees=2 wavesCleared=1
    //   phase=playing sha256=21698bfa5939e984effa7823cc072f6bb9e849b471da632ec6dff53b3c5b0bb8
    func testGoldenRunMechanicsUnchanged() {
        var w = World(level: Self.mechanicsLevel(), hiveStats: Self.mechanicsHive, cardPool: UpgradeCatalog.all, seed: 11)
        w.debugApplyCard(Self.card("guard_bees"))
        w.debugApplyCard(Self.card("pollen_cloud"))
        let s = Self.golden("B", &w, ticks: 600)
        XCTAssertEqual(s.events, 212)
        XCTAssertEqual(s.spawned, 21)
        XCTAssertEqual(s.fired, 116)
        XCTAssertEqual(s.hit, 55)
        XCTAssertEqual(s.killed, 14)
        XCTAssertEqual(s.hiveDamaged, 0)
        XCTAssertEqual(s.waves, 2)
        XCTAssertEqual(s.thresholds, 1)
        XCTAssertEqual(s.cleared, 0)
        XCTAssertEqual(s.gameOver, 0)
        XCTAssertEqual(s.escorts, 2)
        XCTAssertEqual(s.beeHits, 1)
        XCTAssertEqual(s.other, 0)
        XCTAssertEqual(w.hive.hp, 100000, accuracy: 1e-9)
        XCTAssertEqual(w.time, 20, accuracy: 1e-9)
        XCTAssertEqual(w.mobs.count, 7)
        XCTAssertEqual(w.projectiles.count, 2)
        XCTAssertEqual(w.nectar.level, 1)
        XCTAssertEqual(w.nectar.current, 10)
        XCTAssertEqual(w.bees.count, 2)
        XCTAssertEqual(w.wavesCleared, 1)
        XCTAssertEqual(w.phase, .playing)
        XCTAssertEqual(s.sha, "21698bfa5939e984effa7823cc072f6bb9e849b471da632ec6dff53b3c5b0bb8")
    }

    /// Same seed → identical starting draw, per-tick events, pick payloads and end state (only `runID` differs).
    func testSameSeedProducesIdenticalEventStream() {
        var a = World(level: Self.mechanicsLevel(), hiveStats: Self.mechanicsHive, cardPool: UpgradeCatalog.all,
                      startingCardCount: 2, startingCardPool: UpgradeCatalog.milestone1, seed: 5)
        var b = World(level: Self.mechanicsLevel(), hiveStats: Self.mechanicsHive, cardPool: UpgradeCatalog.all,
                      startingCardCount: 2, startingCardPool: UpgradeCatalog.milestone1, seed: 5)
        XCTAssertNotEqual(a.runID, b.runID)
        XCTAssertEqual(a.startingCards, b.startingCards)
        XCTAssertEqual(a.startingCards.map(\.id), ["venom", "royal_jelly"])
        var picks = 0
        for _ in 0..<600 {
            XCTAssertEqual(a.tick(dt: 1.0 / 30), b.tick(dt: 1.0 / 30))
            XCTAssertEqual(a.phase, b.phase)
            if case .pickingCards(let cards) = a.phase {
                guard case .pickingCards(let other) = b.phase else { return XCTFail("b is not picking while a is") }
                XCTAssertEqual(cards, other)
                picks += 1
                a.choose(cards[0])
                b.choose(other[0])
            }
        }
        XCTAssertGreaterThanOrEqual(picks, 1, "the run never opened a pick, so the draw path went unpinned")
        XCTAssertEqual(a.hive, b.hive)
        XCTAssertEqual(a.mobs, b.mobs)
        XCTAssertEqual(a.projectiles, b.projectiles)
        XCTAssertEqual(a.nectar, b.nectar)
        XCTAssertEqual(a.modifiers, b.modifiers)
        XCTAssertEqual(a.bees, b.bees)
        XCTAssertEqual(a.time, b.time)
        XCTAssertEqual(a.wavesCleared, b.wavesCleared)
        XCTAssertEqual(a.phase, b.phase)
    }
}
