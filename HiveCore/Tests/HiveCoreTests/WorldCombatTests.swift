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
    func testBossWaveClearedByContactStillResolvesOnce() {
        // hive survives the bear's contact (hp 100 vs 40) and the bear dies on contact → cleared exactly once, no gameOver
        var w = World(level: oneBearBossLevel(), hiveStats: HiveStats(damage: 0.0001, fireRate: 0.01), seed: 3)
        let ev = run(&w, seconds: 30)
        XCTAssertEqual(w.phase, .cleared)
        XCTAssertEqual(ev.filter { $0 == .levelCleared }.count, 1)
        XCTAssertFalse(ev.contains(.gameOver))
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
