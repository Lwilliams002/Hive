import XCTest
import Foundation
@testable import HiveCore

final class MobBehaviorTests: XCTestCase {
    func level(_ json: String) -> LevelDefinition { try! LevelDefinition.load(from: Data(json.utf8)) }
    /// One hornetQueen boss, nothing else.
    func oneQueenLevel() -> LevelDefinition {
        level(#"{"id":4,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"hornetQueen","count":1,"interval":0}]}]}"#)
    }
    func run(_ w: inout World, seconds: Double) -> [GameEvent] {
        var ev: [GameEvent] = []; var t = 0.0
        while t < seconds { ev += w.tick(dt: 1.0/60); t += 1.0/60 }
        return ev
    }
    func count(_ w: World, _ type: MobType) -> Int { w.mobs.filter { $0.type == type }.count }
    func escortEvents(_ ev: [GameEvent]) -> Int {
        ev.filter { if case .escortSpawned = $0 { return true }; return false }.count
    }
    /// Kills the mob at `index` with a 1-hp set and a stationary projectile on top of it (resolved next tick).
    func debugKill(_ w: inout World, index: Int) {
        let pos = w.mobs[index].position
        w.debugSetMob(index: index, position: pos, hp: 1)
        w.debugAddProjectile(at: pos, velocity: .zero, damage: 10)
    }

    func testNewMobStatsTable() {
        XCTAssertEqual(MobType.beetle.stats, MobStats(maxHP: 90, speed: 40, contactDamage: 25, radius: 13, nectar: 4, isBoss: false, armor: 5))
        XCTAssertEqual(MobType.hornetQueen.stats, MobStats(maxHP: 700, speed: 32, contactDamage: 35, radius: 26, nectar: 20, isBoss: true, armor: 0,
                                                           escort: EscortSpawn(type: .hornet, count: 2, every: 6, first: 3)))
        XCTAssertEqual(MobType.swarmMother.stats, MobStats(maxHP: 380, speed: 45, contactDamage: 25, radius: 22, nectar: 18, isBoss: true, armor: 0,
                                                           escort: EscortSpawn(type: .wasp, count: 4, every: 4, first: 2)))
        XCTAssertEqual(MobType.beetle.rawValue, "beetle")
        XCTAssertEqual(MobType.hornetQueen.rawValue, "hornetQueen")
        XCTAssertEqual(MobType.swarmMother.rawValue, "swarmMother")
        XCTAssertNil(MobType.bear.stats.escort)
        XCTAssertEqual(MobType.wasp.stats.armor, 0)
    }

    func testArmorReducesDamageToMinimumOne() {
        // no director spawns for 100 s; a debug beetle parked at 100 pt takes two stationary hits in one tick
        var w = World(level: level(#"{"id":5,"name":"t","waves":[{"delay":100,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#), seed: 1)
        w.debugAddMob(type: .beetle, position: Vec2(100, 0))
        w.debugAddProjectile(at: Vec2(100, 0), velocity: .zero, damage: 4)
        w.debugAddProjectile(at: Vec2(100, 0), velocity: .zero, damage: 20)
        let ev = w.tick(dt: 1.0/60)
        XCTAssertEqual(ev.filter { if case .mobHit = $0 { return true }; return false }.count, 2)
        XCTAssertEqual(w.mobs[0].hp, 90 - 1 - 15, accuracy: 1e-9)   // max(1, 4−5) + (20−5)
    }

    func testQueenSpawnsEscortsOnSchedule() {
        // escorts at 3 s, then every 6 s; sample at 2.95/3.05/9.05 s to stay clear of the tick boundaries
        var w = World(level: oneQueenLevel(), hiveStats: HiveStats(damage: 0.0001, fireRate: 0.01), seed: 7)
        var ev = run(&w, seconds: 2.95)
        XCTAssertEqual(count(w, .hornet), 0)
        ev += run(&w, seconds: 0.1)
        XCTAssertEqual(count(w, .hornet), 2)
        XCTAssertEqual(escortEvents(ev), 1)
        let queen = w.mobs.first { $0.type == .hornetQueen }!
        let hornetIDs = w.mobs.filter { $0.type == .hornet }.map(\.id)
        XCTAssertTrue(ev.contains(.escortSpawned(parentID: queen.id, ids: hornetIDs)))
        for h in w.mobs where h.type == .hornet {
            // an approaching queen spawns escorts beside itself: same distance from the hive, bearing within ±15°
            XCTAssertEqual(h.position.length, queen.position.length, accuracy: 2)
            let dAngle = abs(remainder(atan2(h.position.y, h.position.x) - atan2(queen.position.y, queen.position.x), 2 * .pi))
            XCTAssertLessThanOrEqual(dAngle, 15.0 * .pi / 180 + 1e-9)
        }
        ev += run(&w, seconds: 6.0)
        XCTAssertEqual(count(w, .hornet), 4)
        XCTAssertEqual(escortEvents(ev), 2)
    }

    func testEscortsStopWhenParentDies() {
        // a slow bear keeps the level alive after the queen dies
        let lvl = level(#"{"id":6,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"hornetQueen","count":1,"interval":0},{"type":"bear","count":1,"interval":0}]}]}"#)
        var w = World(level: lvl, hiveStats: HiveStats(damage: 0.0001, fireRate: 0.01), seed: 7)
        var ev = run(&w, seconds: 2.9)
        let qi = w.mobs.firstIndex { $0.type == .hornetQueen }!
        debugKill(&w, index: qi)
        var t = 2.9
        while t < 3.5 {
            ev += w.tick(dt: 1.0/60); t += 1.0/60
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }   // the queen's 20 nectar opens a pick
        }
        XCTAssertFalse(w.mobs.contains { $0.type == .hornetQueen })
        XCTAssertEqual(count(w, .hornet), 0)
        XCTAssertEqual(escortEvents(ev), 0)
    }

    func testNoEscortsWhilePicking() {
        let lvl = level(#"{"id":7,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"hornetQueen","count":1,"interval":0},{"type":"wasp","count":10,"interval":0}]}]}"#)
        var w = World(level: lvl, hiveStats: HiveStats(damage: 20, fireRate: 5, projectileCount: 1), seed: 2)
        var t = 0.0
        while t < 10 { _ = w.tick(dt: 1.0/60); t += 1.0/60; if case .pickingCards = w.phase { break } }
        guard case .pickingCards(let cards) = w.phase else { return XCTFail("expected pickingCards, got \(w.phase)") }
        let queenTimer = w.mobs.first { $0.type == .hornetQueen }!.escortTimer
        let hornets = count(w, .hornet)
        var ev: [GameEvent] = []
        for _ in 0..<600 { ev += w.tick(dt: 1.0/60) }   // 10 s of ticks while picking: no-ops
        XCTAssertEqual(count(w, .hornet), hornets)
        XCTAssertEqual(escortEvents(ev), 0)
        XCTAssertEqual(w.mobs.first { $0.type == .hornetQueen }!.escortTimer, queenTimer)   // timer frozen
        w.choose(cards[0])
        // after the pick, the queen's next escort arrives once its frozen timer runs out
        var resumed: [GameEvent] = []; t = 0
        while t < queenTimer + 0.5 && escortEvents(resumed) == 0 {
            resumed += w.tick(dt: 1.0/60); t += 1.0/60
            if case .pickingCards(let more) = w.phase { w.choose(more[0]) }
        }
        XCTAssertEqual(escortEvents(resumed), 1)
        XCTAssertEqual(t, queenTimer, accuracy: 1.0/30)
        XCTAssertTrue(w.mobs.contains { $0.type == .hornetQueen })
    }

    func testEscortsKeepWaveAlive() {
        let lvl = level(#"{"id":8,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"hornetQueen","count":1,"interval":0}]},{"delay":0,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#)
        var w = World(level: lvl, hiveStats: HiveStats(damage: 0.0001, fireRate: 0.01), seed: 7)
        var ev = run(&w, seconds: 3.1)
        XCTAssertEqual(count(w, .hornet), 2)
        debugKill(&w, index: w.mobs.firstIndex { $0.type == .hornetQueen }!)
        var t = 0.0
        while t < 1.0 {
            ev += w.tick(dt: 1.0/60); t += 1.0/60
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }
        }
        XCTAssertFalse(w.mobs.contains { $0.type == .hornetQueen })
        XCTAssertEqual(count(w, .hornet), 2)
        XCTAssertFalse(ev.contains(.waveStarted(number: 2, isBoss: false)))
        XCTAssertEqual(w.director.waveNumber, 1)
        XCTAssertEqual(w.phase, .playing)
    }

    func testEscortsSpawnOutsideContactRange() {
        // a queen parked at the hive edge (40 + 26) spawns its escorts 140 pt out, not inside contact range
        var w = World(level: level(#"{"id":10,"name":"t","waves":[{"delay":100,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#),
                      hiveStats: HiveStats(maxHP: 100000, damage: 0.0001, fireRate: 0.01), seed: 7)
        w.debugAddMob(type: .hornetQueen, position: Vec2(Hive.radius + MobType.hornetQueen.stats.radius, 0))
        var t = 0.0; var spawned: [Int] = []
        while t < 4 && spawned.isEmpty {
            for e in w.tick(dt: 1.0/60) { if case .escortSpawned(_, let ids) = e { spawned = ids } }
            t += 1.0/60
        }
        XCTAssertEqual(spawned.count, 2)
        for h in w.mobs where spawned.contains(h.id) {
            XCTAssertGreaterThanOrEqual(h.position.length, 140 - 1e-6)
        }
        XCTAssertEqual(w.mobs.filter { $0.type == .hornet }.count, 2)   // none consumed by contact on the spawn tick
    }
}
