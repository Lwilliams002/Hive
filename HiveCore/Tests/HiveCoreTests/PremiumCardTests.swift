import XCTest
import Foundation
@testable import HiveCore

/// The premium card side stream (M4 rulings R6–R10, R29): the locked pool, `premiumRNG` seeded from
/// `seed ^ premiumSeedSalt`, one 1-in-3 roll per pick open published as `premiumOffer`, cleared by `choose`.
/// The main `rng` is never consumed by the premium path, so pick payloads and event streams are identical
/// with and without a premium pool.
final class PremiumCardTests: XCTestCase {
    /// 10 wasps at once, no delay: 10 nectar crosses the first threshold (8) exactly once with 2 left, so a
    /// `tenWasps` run opens one pick and no chained pick follows `choose`.
    func tenWasps() -> LevelDefinition { try! LevelDefinition.load(from: Data(#"{"id":3,"name":"t","waves":[{"delay":0,"spawns":[{"type":"wasp","count":10,"interval":0}]}]}"#.utf8)) }
    let strongHive = HiveStats(damage: 20, fireRate: 10, projectileCount: 3)
    let god = HiveStats(maxHP: 1_000_000, damage: 500, fireRate: 20, projectileCount: 3)
    let salt: UInt64 = 0x9E37_79B9_7F4A_7C15
    let epics = UpgradeCatalog.locked(unlockedThrough: 0)

    func runUntilPicking(_ w: inout World, max: Double = 30) -> [GameEvent] {
        var ev: [GameEvent] = []; var t = 0.0
        while t < max { ev += w.tick(dt: 1.0/60); t += 1.0/60; if case .pickingCards = w.phase { break } }
        return ev
    }
    /// A `tenWasps` / `strongHive` world run to its first (and only) pick.
    func firstPick(seed: UInt64, premiumPool: [UpgradeCard]) -> World {
        var w = World(level: tenWasps(), hiveStats: strongHive, seed: seed, premiumPool: premiumPool)
        _ = runUntilPicking(&w)
        return w
    }
    func card(_ id: String) -> UpgradeCard { UpgradeCatalog.all.first { $0.id == id }! }
    func ids(_ cards: [UpgradeCard]) -> [String] { cards.map(\.id) }
    func endlessWorld(poolLevel: Int) -> World {
        World(provider: .endless(EndlessConfig()), hiveStats: god, cardPool: UpgradeCatalog.pool(unlockedThrough: poolLevel),
              seed: 5, premiumPool: UpgradeCatalog.locked(unlockedThrough: poolLevel))
    }

    func testLockedPoolComplementsPool() {
        let allIDs = Set(UpgradeCatalog.all.map(\.id))
        for level in [0, 4, 5, 7, 10, 14, 15, 30] {
            let locked = Set(ids(UpgradeCatalog.locked(unlockedThrough: level)))
            let pool = Set(ids(UpgradeCatalog.pool(unlockedThrough: level)))
            XCTAssertEqual(locked.union(pool), allIDs, "level \(level)")
            XCTAssertTrue(locked.isDisjoint(with: pool), "level \(level)")
        }
        // In the order of `all`; story level 1 (poolLevel 0) offers the four epics, not `all − milestone1` (R8).
        XCTAssertEqual(ids(UpgradeCatalog.locked(unlockedThrough: 0)), ["queens_wrath", "swarm_call", "royal_guard", "thick_wax"])
        XCTAssertEqual(ids(UpgradeCatalog.locked(unlockedThrough: 5)), ["swarm_call", "royal_guard", "thick_wax"])
        XCTAssertEqual(ids(UpgradeCatalog.locked(unlockedThrough: 7)), ["swarm_call", "royal_guard"])
        XCTAssertEqual(ids(UpgradeCatalog.locked(unlockedThrough: 10)), ["royal_guard"])
        XCTAssertEqual(ids(UpgradeCatalog.locked(unlockedThrough: 14)), ["royal_guard"])
        XCTAssertTrue(UpgradeCatalog.locked(unlockedThrough: 15).isEmpty)   // R9: the slot is hidden from poolLevel 15
    }

    func testChooseAcceptsCardNotInOffer() {
        // R6: taking the premium card is a plain `choose`; `choose` accepts a card outside both the offer and `cardPool`.
        var w = firstPick(seed: 2, premiumPool: [])
        guard case .pickingCards(let cards) = w.phase else { return XCTFail("expected pickingCards, got \(w.phase)") }
        XCTAssertFalse(cards.contains { $0.id == "royal_guard" })   // the pool is milestone1
        XCTAssertNil(w.premiumOffer)
        w.choose(card("royal_guard"))
        XCTAssertEqual(w.bees.count, 3)
        XCTAssertEqual(w.modifiers.beeDamage, 12, accuracy: 1e-9)
        XCTAssertEqual(w.phase, .playing)
    }

    func testPremiumPoolDoesNotPerturbMainDraw() {
        // R29: premium pool `[]` vs non-empty → identical event streams, `.pickingCards` payloads and end state.
        var offers = 0
        for seed in 1...30 {
            var a = World(level: tenWasps(), hiveStats: strongHive, seed: UInt64(seed), premiumPool: [])
            var b = World(level: tenWasps(), hiveStats: strongHive, seed: UInt64(seed), premiumPool: epics)
            for _ in 0..<600 {
                XCTAssertEqual(a.tick(dt: 1.0/60), b.tick(dt: 1.0/60), "seed \(seed)")
                XCTAssertEqual(a.phase, b.phase, "seed \(seed)")
                if case .pickingCards(let cards) = a.phase {
                    guard case .pickingCards(let other) = b.phase else { return XCTFail("seed \(seed): b is not picking while a is") }
                    XCTAssertEqual(cards, other, "seed \(seed)")
                    XCTAssertEqual(cards.count, 3, "seed \(seed)")
                    XCTAssertNil(a.premiumOffer, "seed \(seed)")   // R10: an empty pool never offers
                    if b.premiumOffer != nil { offers += 1 }
                    a.choose(cards[0])
                    b.choose(other[0])
                }
            }
            XCTAssertEqual(a.hive, b.hive, "seed \(seed)")
            XCTAssertEqual(a.mobs, b.mobs, "seed \(seed)")
            XCTAssertEqual(a.nectar, b.nectar, "seed \(seed)")
            XCTAssertEqual(a.time, b.time, "seed \(seed)")
        }
        XCTAssertGreaterThan(offers, 0, "no seed in 1...30 rolled a premium offer, so the side stream went unexercised")
    }

    func testPremiumOfferNeverInMainDraw() {
        // The payload stays exactly the three `cardPool` cards; the offer travels in `premiumOffer` and comes from the locked pool.
        var offers = 0
        for seed in 1...30 {
            var w = World(level: tenWasps(), hiveStats: strongHive, seed: UInt64(seed), premiumPool: epics)
            for _ in 0..<600 {
                _ = w.tick(dt: 1.0/60)
                if case .pickingCards(let cards) = w.phase {
                    if let offer = w.premiumOffer {
                        offers += 1
                        XCTAssertFalse(cards.contains(offer), "seed \(seed)")
                        XCTAssertTrue(epics.contains(offer), "seed \(seed)")
                        XCTAssertFalse(UpgradeCatalog.milestone1.contains(offer), "seed \(seed)")
                    }
                    w.choose(cards[0])
                }
            }
        }
        XCTAssertGreaterThan(offers, 0)
    }

    func testPremiumOfferEmptyWhenPoolLevelFifteen() {
        // R9/R10: from poolLevel 15 the locked pool is empty, no roll is made and the slot stays hidden.
        var w = endlessWorld(poolLevel: 15)
        XCTAssertTrue(w.premiumPool.isEmpty)
        var picks = 0
        var t = 0.0
        while t < 300 && picks < 5 {
            _ = w.tick(dt: 1.0/60)
            while case .pickingCards(let cards) = w.phase, picks < 5 {
                XCTAssertNil(w.premiumOffer, "pick \(picks)")
                picks += 1
                w.choose(cards[0])
            }
            t += 1.0/60
        }
        XCTAssertEqual(picks, 5)
    }

    func testPremiumRollIsDeterministicForSeed() {
        // R7/R10: the offer of every pick is exactly what a replica of the side stream (seed ^ salt) rolls and draws.
        XCTAssertEqual(ids(UpgradeCatalog.locked(unlockedThrough: 10)), ["royal_guard"])
        func offers(_ w: inout World, replica side: inout SeededRNG) -> [UpgradeCard?] {
            var seen: [UpgradeCard?] = []
            var t = 0.0
            while t < 300 && seen.count < 5 {
                _ = w.tick(dt: 1.0/60)
                // Re-testing the phase after `choose` catches a chained pick, which rolls afresh.
                while case .pickingCards(let cards) = w.phase, seen.count < 5 {
                    let expected = side.unitDouble() < 1.0 / 3.0
                        ? UpgradeCatalog.draw(count: 1, from: w.premiumPool, rng: &side, epicWeight: min(25, 5 + 3 * w.nectar.level)).first
                        : nil
                    XCTAssertEqual(w.premiumOffer, expected, "pick \(seen.count)")
                    seen.append(w.premiumOffer)
                    w.choose(cards[0])
                }
                t += 1.0/60
            }
            return seen
        }
        var first = endlessWorld(poolLevel: 10)
        var side1 = SeededRNG(seed: 5 ^ salt)
        let firstOffers = offers(&first, replica: &side1)
        XCTAssertEqual(firstOffers.count, 5)
        var second = endlessWorld(poolLevel: 10)
        var side2 = SeededRNG(seed: 5 ^ salt)
        XCTAssertEqual(offers(&second, replica: &side2), firstOffers)   // same seed → the same 5 offers
    }

    func testPremiumOfferClearedByChoose() {
        var offered: [World] = []
        for seed in 1...60 {
            let w = firstPick(seed: UInt64(seed), premiumPool: epics)
            if w.premiumOffer != nil { offered.append(w) }
            if offered.count == 2 { break }
        }
        guard offered.count == 2 else { return XCTFail("fewer than two seeds in 1...60 rolled an offer") }

        // Taking a regular card clears the offer (R7).
        var regular = offered[0]
        guard case .pickingCards(let cards) = regular.phase else { return XCTFail("expected pickingCards") }
        regular.choose(cards[0])
        XCTAssertNil(regular.premiumOffer)
        XCTAssertEqual(regular.phase, .playing)

        // Taking the premium card clears the offer and applies the locked card for this run (R6: replace, not add).
        var premium = offered[1]
        guard let offer = premium.premiumOffer else { return XCTFail("expected an offer") }
        premium.choose(offer)
        XCTAssertNil(premium.premiumOffer)
        XCTAssertEqual(premium.phase, .playing)
        switch offer.id {
        case "queens_wrath": XCTAssertEqual(premium.hive.stats.damage, 32, accuracy: 1e-9)   // 20 × 1.6
        case "swarm_call": XCTAssertEqual(premium.hive.stats.projectileCount, 5)
        case "royal_guard": XCTAssertEqual(premium.bees.count, 3); XCTAssertEqual(premium.modifiers.beeDamage, 12, accuracy: 1e-9)
        case "thick_wax": XCTAssertEqual(premium.modifiers.contactResist, 0.3, accuracy: 1e-9)
        default: XCTFail("unexpected premium offer \(offer.id)")
        }
    }

    func testPremiumRollRateAboutOneInThree() {
        var offers = 0
        for seed in 1...300 {
            let w = firstPick(seed: UInt64(seed), premiumPool: epics)
            guard case .pickingCards = w.phase else { XCTFail("seed \(seed) never opened a pick"); continue }
            if w.premiumOffer != nil { offers += 1 }
        }
        XCTAssertTrue((70...130).contains(offers), "offers = \(offers); expected ≈ 100 (σ ≈ 8.2)")
        // The first roll of every run is the first value of its side stream (seed ^ salt): 88 of 300 (measured 2026-10-24).
        let firstRolls = (1...300).filter { var r = SeededRNG(seed: UInt64($0) ^ salt); return r.unitDouble() < 1.0 / 3.0 }.count
        XCTAssertEqual(firstRolls, 88)
        XCTAssertEqual(offers, firstRolls)
    }
}
