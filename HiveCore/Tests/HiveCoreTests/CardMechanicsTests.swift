import XCTest
import Foundation
@testable import HiveCore

final class CardMechanicsTests: XCTestCase {
    /// A level whose only wave starts after 100 s, so tests place mobs by hand and the run never clears.
    func emptyLevel() -> LevelDefinition {
        try! LevelDefinition.load(from: Data(#"{"id":9,"name":"t","waves":[{"delay":100,"spawns":[{"type":"wasp","count":1,"interval":0}]}]}"#.utf8))
    }
    func oneBearBossLevel() -> LevelDefinition {
        try! LevelDefinition.load(from: Data(#"{"id":2,"name":"t","waves":[{"delay":0,"isBoss":true,"spawns":[{"type":"bear","count":1,"interval":0}]}]}"#.utf8))
    }
    /// Hive that never fires, so only the mechanic under test deals damage.
    let silentHive = HiveStats(projectileCount: 0)
    func card(_ id: String) -> UpgradeCard { UpgradeCatalog.all.first { $0.id == id }! }
    func ticks(_ w: inout World, _ n: Int) -> [GameEvent] {
        var ev: [GameEvent] = []
        for _ in 0..<n { ev += w.tick(dt: 1.0 / 60) }
        return ev
    }

    func testCatalogHasThirteenCardsWithUniqueIDs() {
        XCTAssertEqual(UpgradeCatalog.all.count, 13)
        XCTAssertEqual(Set(UpgradeCatalog.all.map(\.id)).count, 13)
        XCTAssertEqual(Array(UpgradeCatalog.all.prefix(6)), UpgradeCatalog.milestone1)
        XCTAssertEqual(UpgradeCatalog.milestone1.count, 6)
    }

    func testPoolExcludesLockedCards() {
        let four = UpgradeCatalog.pool(unlockedThrough: 4)
        XCTAssertFalse(four.contains { $0.rarity == .epic })
        XCTAssertEqual(four.count, 9)
        let ten = Set(UpgradeCatalog.pool(unlockedThrough: 10).map(\.id))
        XCTAssertTrue(ten.isSuperset(of: ["queens_wrath", "swarm_call", "thick_wax"]))
        XCTAssertFalse(ten.contains("royal_guard"))
        XCTAssertEqual(UpgradeCatalog.pool(unlockedThrough: 15).count, 13)
    }

    func testEpicWeightScalesWithNectarLevel() {
        let commons = UpgradeCatalog.milestone1.filter { $0.rarity == .common }
        XCTAssertEqual(commons.count, 4)
        let pool = commons + [card("queens_wrath")]
        var rng = SeededRNG(seed: 21); var epic = 0
        for _ in 0..<3000 {
            if UpgradeCatalog.draw(count: 1, from: pool, rng: &rng, epicWeight: 25)[0].rarity == .epic { epic += 1 }
        }
        // 25 / (25 + 4·70) ≈ 8.2%
        XCTAssert(epic >= 180 && epic <= 330, "epic drawn \(epic) times")
    }

    func testSlowFieldSlowsOnlyInsideRadius() {
        var w = World(level: emptyLevel(), hiveStats: silentHive, seed: 1)
        w.debugApplyCard(card("honey_field"))
        // Near wasp starts at 150 (not the brief's 100): at 100 it would cross the 50-pt contact edge before 1 s.
        w.debugAddMob(type: .wasp, position: Vec2(500, 0))
        w.debugAddMob(type: .wasp, position: Vec2(0, 150))
        _ = ticks(&w, 60)
        XCTAssertEqual(w.mobs.count, 2)
        XCTAssertEqual(500 - w.mobs[0].position.length, 90, accuracy: 1e-6)
        XCTAssertEqual(150 - w.mobs[1].position.length, 58.5, accuracy: 1e-6)
    }

    func testGuardBeesOrbitAndHit() {
        var w = World(level: emptyLevel(), hiveStats: silentHive, seed: 1)
        w.debugApplyCard(card("guard_bees"))
        XCTAssertEqual(w.bees.count, 2)
        w.debugAddMob(type: .wasp, position: Vec2(72, 0))
        var hitAt: Int?
        for i in 0..<90 {    // 1.5 s
            w.debugSetMob(index: 0, position: Vec2(72, 0), hp: w.mobs[0].hp)   // park on the orbit
            let ev = w.tick(dt: 1.0 / 60)
            if ev.contains(.beeHit(mobID: w.mobs[0].id)) { hitAt = i; break }
        }
        XCTAssertNotNil(hitAt, "no bee hit within 1.5 s")
        XCTAssertEqual(w.mobs[0].hp, 20 - 6, accuracy: 1e-9)
        // Bee positions lie on the 72-pt orbit, evenly spaced.
        let p = w.beePositions
        XCTAssertEqual(p.count, 2)
        XCTAssertEqual(p[0].length, 72, accuracy: 1e-9)
        XCTAssertEqual(p[0].distance(to: p[1]), 144, accuracy: 1e-9)
    }

    func testSplashHitsNeighborsOnce() {
        var w = World(level: emptyLevel(), hiveStats: silentHive, seed: 1)
        w.debugApplyCard(card("pollen_cloud"))
        w.debugAddMob(type: .wasp, position: Vec2(200, 0))
        w.debugAddMob(type: .wasp, position: Vec2(200, 25))
        w.debugAddMob(type: .wasp, position: Vec2(200, -25))
        w.debugAddProjectile(at: Vec2(200, 0), velocity: .zero, damage: 10)
        let ev = w.tick(dt: 1.0 / 60)
        // One direct hit plus two splash hits (splashed mobs also report `.mobHit` so they flash).
        XCTAssertEqual(ev.filter { if case .mobHit = $0 { return true }; return false }.count, 3)
        XCTAssertEqual(w.mobs.map(\.hp), [10, 16, 16])
        XCTAssertTrue(w.projectiles.isEmpty)
        // No chaining: further ticks change nothing.
        _ = ticks(&w, 5)
        XCTAssertEqual(w.mobs.map(\.hp), [10, 16, 16])
    }

    func testContactResistReducesHiveDamage() {
        var w = World(level: oneBearBossLevel(), hiveStats: silentHive, seed: 1)
        w.debugApplyCard(card("thick_wax"))
        _ = w.tick(dt: 1.0 / 60)
        w.debugSetMob(index: 0, position: Vec2(Hive.radius + 30 + 0.1, 0), hp: 450)
        let ev = w.tick(dt: 1.0 / 60)
        XCTAssertTrue(ev.contains { if case .hiveDamaged(let a, _) = $0 { return abs(a - 28) < 1e-9 }; return false })
        XCTAssertEqual(w.hive.hp, 72, accuracy: 1e-9)
    }

    func testRoyalGuardAddsBeesAndDoublesDamage() {
        var w = World(level: emptyLevel(), seed: 1)
        w.debugApplyCard(card("guard_bees"))
        w.debugApplyCard(card("royal_guard"))
        XCTAssertEqual(w.bees.count, 5)
        XCTAssertEqual(w.modifiers.guardBeeCount, 5)
        XCTAssertEqual(w.modifiers.beeDamage, 12, accuracy: 1e-9)
        XCTAssertEqual(Set(w.bees.map(\.id)).count, 5)
    }

    func testRunModifiersStacking() {
        var m = RunModifiers()
        m.apply(.slowField(radius: 160, factor: 0.65))
        m.apply(.slowField(radius: 120, factor: 0.65))
        XCTAssertEqual(m.slowFactor, 0.4225, accuracy: 1e-9)
        XCTAssertEqual(m.slowRadius, 160)
        m.apply(.contactResist(0.3)); m.apply(.contactResist(0.3))
        XCTAssertEqual(m.contactResist, 0.51, accuracy: 1e-9)
        m.apply(.damageMultiplier(2))     // stat effects are ignored here
        XCTAssertEqual(m.slowFactor, 0.4225, accuracy: 1e-9)
    }
}
