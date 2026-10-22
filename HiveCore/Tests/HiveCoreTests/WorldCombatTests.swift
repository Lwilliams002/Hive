import XCTest
import Foundation
@testable import HiveCore

final class WorldCombatTests: XCTestCase {
    /// one wave, one wasp, no delay
    func oneWaspLevel() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":1,"name":"t","waves":[{"delay":0,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#.utf8)) }
    func oneBearBossLevel() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":2,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"bear","count":1,"interval":0}]}]}"#.utf8)) }
    func run(_ w: inout World, seconds: Double) -> [GameEvent] { var ev: [GameEvent] = []; var t = 0.0; while t < seconds { ev += w.tick(dt: 1.0/60); t += 1.0/60 }; return ev }

    func testTickWithZeroDtChangesNothing() {
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = w.tick(dt: 1.0/60)
        let before = (w.mobs, w.projectiles, w.hive, w.time)
        XCTAssertEqual(w.tick(dt: 0), [])
        XCTAssertEqual(w.mobs, before.0); XCTAssertEqual(w.projectiles, before.1); XCTAssertEqual(w.hive, before.2); XCTAssertEqual(w.time, before.3)
    }
    func testWaspSpawnsOnSpawnRadius() {
        var w = World(level: oneWaspLevel(), seed: 1)
        let ev = w.tick(dt: 1.0/60)
        XCTAssertTrue(ev.contains(.mobSpawned(id: w.mobs[0].id, type: .wasp)))
        XCTAssertTrue(ev.contains(.waveStarted(number: 1, isBoss: false)))
        XCTAssertEqual(w.mobs[0].position.length, World.spawnRadius, accuracy: 1e-6)
    }
    func testHiveFiresAtNearestMobAtFireRate() {
        var w = World(level: oneWaspLevel(), seed: 1)
        let ev = run(&w, seconds: 0.9)
        let shots = ev.filter { if case .projectileFired = $0 { return true }; return false }.count
        XCTAssertEqual(shots, 2)   // fireRate 2/s: shots at t≈0 and t≈0.5; 0.9 s avoids the boundary at 1.0
    }
    func testWaspDiesBeforeReachingHiveAndLevelClears() {
        var w = World(level: oneWaspLevel(), seed: 1)
        let ev = run(&w, seconds: 8.0)
        XCTAssertTrue(ev.contains { if case .mobKilled(_, .wasp, _) = $0 { return true }; return false })
        XCTAssertFalse(ev.contains { if case .hiveDamaged = $0 { return true }; return false })
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(ev.filter { $0 == .levelCleared }.count, 1)
        XCTAssertTrue(w.mobs.isEmpty)
    }
    func testKilledMobDoesNotDealContactDamage() {
        // hive does 10 dmg per shot; wasp has 20 hp; put a wasp at the hive edge with 10 hp and a projectile on top of it
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = w.tick(dt: 1.0/60)
        w.debugSetMob(index: 0, position: Vec2(Hive.radius + 10 + 0.5, 0), hp: 10)
        w.debugAddProjectile(at: Vec2(Hive.radius + 10 + 0.5, 0), velocity: .zero, damage: 10)
        let ev = w.tick(dt: 1.0/60)
        XCTAssertTrue(ev.contains { if case .mobKilled = $0 { return true }; return false })
        XCTAssertFalse(ev.contains { if case .hiveDamaged = $0 { return true }; return false })
        XCTAssertEqual(w.hive.hp, 100)
    }
    func testContactDamageAndGameOver() {
        var w = World(level: oneBearBossLevel(), hiveStats: HiveStats(maxHP: 30, damage: 0.0001, fireRate: 0.01), seed: 3)
        let ev = run(&w, seconds: 30)
        XCTAssertTrue(ev.contains(.hiveDamaged(amount: 40, hp: -10)))
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(ev.filter { $0 == .gameOver }.count, 1)
        XCTAssertFalse(ev.contains(.levelCleared))
    }
    func testBossStopsAtHiveEdgeAndOutdamagesHive() {
        // bear: 520 → edge at 70, speed 28 → arrives ≈16.1 s; 40 dmg on arrival then every 1 s → hp 60, 20, -20
        var w = World(level: oneBearBossLevel(), hiveStats: HiveStats(damage: 0.0001, fireRate: 0.01), seed: 3)
        let edge = Hive.radius + MobType.bear.stats.radius
        var ev = run(&w, seconds: 16.5)
        XCTAssertEqual(w.mobs.count, 1)
        XCTAssertEqual(w.mobs[0].position.length, edge, accuracy: 1e-6)
        ev += run(&w, seconds: 0.4)
        XCTAssertEqual(w.mobs[0].position.length, edge, accuracy: 1e-6)   // stays parked
        ev += run(&w, seconds: 40 - 16.9)
        XCTAssertEqual(w.mobs.first?.position.length ?? 0, edge, accuracy: 1e-6)
        let hits = ev.compactMap { e -> GameEvent? in if case .hiveDamaged = e { return e }; return nil }
        XCTAssertEqual(hits, [.hiveDamaged(amount: 40, hp: 60), .hiveDamaged(amount: 40, hp: 20), .hiveDamaged(amount: 40, hp: -20)])
        XCTAssertEqual(w.phase, .gameOver)
        XCTAssertEqual(ev.filter { $0 == .gameOver }.count, 1)
        XCTAssertFalse(ev.contains(.levelCleared))
    }
    func testBossKilledAtEdgeClearsLevelOnce() {
        var w = World(level: oneBearBossLevel(), hiveStats: HiveStats(maxHP: 100000, damage: 50, fireRate: 10), seed: 3)
        // the bear's 15 nectar crosses the first threshold, so resolve the card pick to let the clear check run
        var ev: [GameEvent] = []; var t = 0.0
        while t < 40 {
            ev += w.tick(dt: 1.0/60); t += 1.0/60
            if case .pickingCards(let cards) = w.phase { w.choose(cards[0]) }
        }
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(ev.filter { $0 == .levelCleared }.count, 1)
        XCTAssertFalse(ev.contains(.gameOver))
        XCTAssertTrue(w.mobs.isEmpty)
    }
    func testHugeDtIsClampedToOneThirtieth() {
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = w.tick(dt: 1.0/60)
        let spawn = w.mobs[0].position
        let ev = w.tick(dt: 10)
        XCTAssertLessThanOrEqual(ev.filter { if case .projectileFired = $0 { return true }; return false }.count, 1)
        XCTAssertEqual(w.mobs.count, 1)
        XCTAssertLessThanOrEqual(w.mobs[0].position.distance(to: spawn), 90.0 / 30 + 1e-9)
    }
    func testPierceHitsSecondMobOnce() {
        var w = World(level: oneWaspLevel(), hiveStats: HiveStats(pierce: 1), seed: 1)
        _ = w.tick(dt: 1.0/60)
        w.debugSetMob(index: 0, position: Vec2(200, 0), hp: 20)
        w.debugAddMob(type: .wasp, position: Vec2(230, 0))
        w.debugAddProjectile(at: Vec2(190, 0), velocity: Vec2(600, 0), damage: 5)
        let ev = run(&w, seconds: 0.2)
        XCTAssertEqual(ev.filter { if case .mobHit = $0 { return true }; return false }.count, 2)
    }
    func testTicksAfterTerminalPhaseAreNoOps() {
        var w = World(level: oneWaspLevel(), seed: 1)
        _ = run(&w, seconds: 8)
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(w.tick(dt: 1.0/60), [])
    }
}
