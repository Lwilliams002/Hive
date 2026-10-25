import Foundation

public struct World {
    public private(set) var hive: Hive
    public internal(set) var mobs: [Mob] = []
    public private(set) var projectiles: [Projectile] = []
    public private(set) var director: WaveDirector
    public private(set) var phase: RunPhase = .playing
    public private(set) var time: Double = 0
    public private(set) var nectar = NectarMeter()
    public private(set) var modifiers = RunModifiers()
    /// Guard bees orbiting the hive (`modifiers.guardBeeCount` of them).
    public internal(set) var bees: [GuardBee] = []

    public static let spawnRadius: Double = 520

    public let runID: UUID
    public private(set) var startingCards: [UpgradeCard] = []
    /// Whether the hive may be revived once this run (the app passes true once the ad system is started; R3).
    /// False means the hive falls straight to `.gameOver`, so headless runs and probes never see `.downed`.
    public private(set) var reviveAllowed: Bool
    /// True once `revive()` has been used; a second fall goes straight to `.gameOver` (R2).
    public private(set) var reviveUsed = false

    private let provider: WaveProvider
    public var isEndless: Bool { provider.isEndless }
    /// Waves whose mobs were all killed after the wave finished issuing (counted once per wave).
    public private(set) var wavesCleared = 0
    private let cardPool: [UpgradeCard]
    var rng: SeededRNG
    /// Shared id counter for mobs and projectiles.
    private var nextID = 1
    /// Waves announced via `waveStarted` so far.
    private var wavesStarted = 0
    /// Spawns still owed by the current wave before the next director spawn means a new wave.
    private var spawnsLeftInWave = 0
    /// Extra card picks owed when one tick's kills crossed more than one nectar threshold.
    private var pendingPicks = 0

    static let hitFlashDuration = 0.08
    /// Seconds between hits from a boss parked at the hive edge.
    private static let bossAttackInterval = 1.0
    private static let spreadRadians = 10.0 * .pi / 180
    /// Escorts never spawn closer to the hive than this (≈1.5 s of hive fire before contact).
    static let escortMinDistance = 140.0
    static let escortJitterRadians = 15.0 * .pi / 180
    /// Revive (R4): hp is restored to this fraction of max; bosses wait at least `reviveBossDelay` before their
    /// next hit; non-boss mobs inside `reviveClearRadius` are pushed out to its edge.
    static let reviveHPFraction = 0.5
    static let reviveBossDelay = 1.5
    static let reviveClearRadius = 150.0

    public init(level: LevelDefinition, hiveStats: HiveStats = .base,
                cardPool: [UpgradeCard] = UpgradeCatalog.milestone1,
                startingCardCount: Int = 0, startingCardPool: [UpgradeCard]? = nil, seed: UInt64,
                reviveAllowed: Bool = false) {
        self.init(provider: .fixed(level), hiveStats: hiveStats, cardPool: cardPool,
                  startingCardPool: startingCardPool, startingCardCount: startingCardCount, seed: seed,
                  reviveAllowed: reviveAllowed)
    }

    public init(provider: WaveProvider, hiveStats: HiveStats = .base,
                cardPool: [UpgradeCard] = UpgradeCatalog.milestone1,
                startingCardPool: [UpgradeCard]? = nil, startingCardCount: Int = 0, seed: UInt64,
                reviveAllowed: Bool = false) {
        self.provider = provider
        self.cardPool = cardPool
        self.runID = UUID()
        self.director = WaveDirector(provider: provider)
        self.hive = Hive(stats: hiveStats, hp: hiveStats.maxHP, cooldown: 0)
        self.reviveAllowed = reviveAllowed
        self.rng = SeededRNG(seed: seed)
        let drawn = UpgradeCatalog.draw(count: startingCardCount, from: startingCardPool ?? cardPool, rng: &rng)
        for card in drawn { apply(card: card) }
        self.startingCards = drawn
    }

    @discardableResult
    public mutating func tick(dt: Double) -> [GameEvent] {
        guard phase == .playing else { return [] }
        // (1)
        guard dt > 0 else { return [] }
        // Clamp large frame gaps (backgrounding, hitches) so one tick never tunnels mobs or bursts fire.
        let dt = min(dt, 1.0 / 30)
        var events: [GameEvent] = []

        // (2)
        time += dt

        // (3) director → spawns
        let spawns = director.tick(dt: dt, aliveMobs: mobs.count)
        let preexistingMobCount = mobs.count
        if !spawns.isEmpty {
            // Every wave issues its first spawn on the tick it starts, so a non-empty
            // batch after the previous wave's spawns are exhausted marks a new wave.
            if spawnsLeftInWave <= 0, let wave = provider.wave(at: wavesStarted) {
                wavesStarted += 1
                spawnsLeftInWave = wave.spawns.reduce(0) { $0 + $1.count }
                events.append(.waveStarted(number: wavesStarted, isBoss: wave.isBoss))
            }
            spawnsLeftInWave -= spawns.count
            let hpScale = director.currentHpScale
            for type in spawns {
                let angle = rng.unitDouble() * 2 * .pi
                let mob = Mob(id: makeID(), type: type,
                              position: Vec2(cos(angle), sin(angle)) * World.spawnRadius, hpScale: hpScale)
                mobs.append(mob)
                events.append(.mobSpawned(id: mob.id, type: type))
            }
        }

        // (3b) boss escorts. Only mobs present now (including this tick's spawns) count down; escorts are
        // appended after `preexistingMobCount`, so like other new spawns they skip movement this tick.
        tickEscorts(dt: dt, events: &events)

        // (4) move mobs toward origin; newly spawned mobs skip movement on their spawn tick so they start exactly on the spawn radius.
        // Bosses stop at the hive edge (Hive.radius + their radius) instead of overlapping it.
        for i in 0..<preexistingMobCount {
            let pos = mobs[i].position
            let stats = mobs[i].type.stats
            let slowed = modifiers.slowRadius > 0 && pos.length < modifiers.slowRadius
            let step = stats.speed * (slowed ? modifiers.slowFactor : 1) * dt
            let dist = pos.length
            if stats.isBoss {
                let edge = Hive.radius + stats.radius
                if dist <= edge { continue }
                mobs[i].position = dist - step <= edge ? pos.normalized * edge : pos - pos.normalized * step
            } else {
                mobs[i].position = step >= dist ? .zero : pos - pos.normalized * step
            }
        }

        // (5) move projectiles; drop out-of-range
        for i in projectiles.indices {
            projectiles[i].position = projectiles[i].position + projectiles[i].velocity * dt
        }
        projectiles.removeAll { $0.position.length > Projectile.maxRange }

        // (6) projectile–mob collisions
        var deadIDs = Set<Int>()
        var spentProjectiles = Set<Int>()
        var thresholdsCrossed = 0
        for p in projectiles.indices {
            for m in mobs.indices {
                let mob = mobs[m]
                if deadIDs.contains(mob.id) || projectiles[p].hitMobIDs.contains(mob.id) { continue }
                let reach = mob.type.stats.radius + Projectile.radius
                guard projectiles[p].position.distance(to: mob.position) < reach else { continue }
                let raw = projectiles[p].damage
                damage(raw, to: &mobs[m])
                mobs[m].hitFlash = World.hitFlashDuration
                projectiles[p].hitMobIDs.append(mob.id)
                events.append(.mobHit(id: mob.id))
                if mobs[m].hp <= 0 {
                    registerKill(m, deadIDs: &deadIDs, thresholds: &thresholdsCrossed, events: &events)
                }
                applySplash(from: m, raw: raw, deadIDs: &deadIDs, thresholds: &thresholdsCrossed, events: &events)
                projectiles[p].pierceRemaining -= 1
                if projectiles[p].pierceRemaining < 0 {
                    spentProjectiles.insert(projectiles[p].id)
                    break
                }
            }
        }
        projectiles.removeAll { spentProjectiles.contains($0.id) }

        // (7) remove dead mobs
        mobs.removeAll { deadIDs.contains($0.id) }
        countClearedWave()

        // Nectar threshold: pause into card pick, skipping the rest of the tick — unless this kill also
        // empties the level, in which case the pick is skipped (nectar carries over) and step 12 clears.
        if openPickUnlessClearing(thresholds: thresholdsCrossed, events: &events) { return events }

        // (8) mob–hive contact. Non-boss mobs deal contact damage once and are removed.
        // Bosses parked at the hive edge stay alive and hit once on arrival, then every `bossAttackInterval` seconds.
        // Contact damage is reduced by `modifiers.contactResist`.
        var contacted = Set<Int>()
        let contactScale = 1 - modifiers.contactResist
        for i in mobs.indices {
            let stats = mobs[i].type.stats
            let edge = Hive.radius + stats.radius
            let dist = mobs[i].position.length
            let amount = stats.contactDamage * contactScale
            if stats.isBoss {
                guard dist <= edge + 1e-6 else { continue }
                mobs[i].attackCooldown -= dt
                if mobs[i].attackCooldown <= 0 {
                    hive.hp -= amount
                    events.append(.hiveDamaged(amount: amount, hp: hive.hp))
                    mobs[i].attackCooldown += World.bossAttackInterval
                }
            } else if dist < edge {
                hive.hp -= amount
                events.append(.hiveDamaged(amount: amount, hp: hive.hp))
                contacted.insert(mobs[i].id)
            }
        }
        mobs.removeAll { contacted.contains($0.id) }

        // (9) the hive fell: downed (awaiting the revive decision) while a revive is permitted and unused,
        // otherwise game over. `.gameOver` is emitted exactly once per run, here or in `abandonRevive()` (R1, R2).
        if hive.hp <= 0 {
            if reviveAllowed && !reviveUsed {
                phase = .downed
                events.append(.hiveDowned)
            } else {
                phase = .gameOver
                events.append(.gameOver)
            }
            return events
        }

        // (10) hive fire
        hive.cooldown -= dt
        while hive.cooldown <= 0 {
            guard let target = nearestMob() else {
                hive.cooldown = max(hive.cooldown, 0)
                break
            }
            fireVolley(at: target.position, events: &events)
            hive.cooldown += 1 / hive.stats.fireRate
        }

        // (10b) guard bees: positions derived from `time`; each bee hits a touching mob at most every
        // `GuardBee.hitCooldown` seconds. Mobs killed here are removed this tick.
        if tickBees(dt: dt, events: &events) { return events }

        // (11) decay hit flash
        for i in mobs.indices {
            mobs[i].hitFlash = max(0, mobs[i].hitFlash - dt)
        }

        // (12) cleared
        countClearedWave()
        if phase == .playing && director.allSpawnsIssued && mobs.isEmpty {
            phase = .cleared
            events.append(.levelCleared)
        }
        return events
    }

    /// Applies the chosen card, then offers the next pick if another threshold is already earned
    /// (several crossed in one tick, or excess nectar covering the next threshold); otherwise resumes play.
    /// No-op outside `.pickingCards`.
    public mutating func choose(_ card: UpgradeCard) {
        guard case .pickingCards = phase else { return }
        apply(card: card)
        if pendingPicks > 0 {
            pendingPicks -= 1
            openPick()
        } else if nectar.add(0) {
            openPick()
        } else {
            phase = .playing
        }
    }

    /// Revives the downed hive (once per run, R4): hp is set to `reviveHPFraction` of max (set, not added — it is
    /// negative), every boss waits at least `reviveBossDelay` before its next hit, every non-boss mob inside
    /// `reviveClearRadius` is displaced (never removed: no kill, no nectar) to `reviveClearRadius + radius` along
    /// its bearing from the hive (a mob exactly at the origin takes bearing 0), and play resumes with the same
    /// `runID`. Projectiles, bees, `hive.cooldown`, nectar, `time` and escort timers are untouched; no rng, no
    /// event (R2 names only `.hiveDowned` and `.gameOver`). Returns `[]`; a no-op outside `.downed`.
    @discardableResult
    public mutating func revive() -> [GameEvent] {
        guard phase == .downed else { return [] }
        reviveUsed = true
        hive.hp = World.reviveHPFraction * hive.stats.maxHP
        for i in mobs.indices {
            let stats = mobs[i].type.stats
            if stats.isBoss {
                mobs[i].attackCooldown = max(mobs[i].attackCooldown, World.reviveBossDelay)
            } else if mobs[i].position.length < World.reviveClearRadius {
                let pos = mobs[i].position
                let bearing = pos.length == 0 ? Vec2(1, 0) : pos.normalized
                mobs[i].position = bearing * (World.reviveClearRadius + stats.radius)
            }
        }
        phase = .playing
        return []
    }

    /// Declines the revive: the downed hive falls for good, emitting the run's single `.gameOver` (R2).
    /// A no-op (returns `[]`) outside `.downed`.
    @discardableResult
    public mutating func abandonRevive() -> [GameEvent] {
        guard phase == .downed else { return [] }
        phase = .gameOver
        return [.gameOver]
    }

    private mutating func apply(card: UpgradeCard) {
        var stats = hive.stats
        stats.apply(card.effect, to: &hive)
        hive.stats = stats
        modifiers.apply(card.effect)
        while bees.count < modifiers.guardBeeCount {
            bees.append(GuardBee(id: bees.count))
        }
    }

    // MARK: - Helpers

    /// Counts the running wave as cleared once it has issued everything and no mob is left (once per wave).
    mutating func countClearedWave() {
        if wavesCleared < wavesStarted && director.currentWaveFullyIssued && mobs.isEmpty {
            wavesCleared += 1
        }
    }

    private mutating func drawCards() -> [UpgradeCard] {
        UpgradeCatalog.draw(count: 3, from: cardPool, rng: &rng, epicWeight: min(25, 5 + 3 * nectar.level))
    }

    /// The single pick-open site: every `.pickingCards` phase is entered through here.
    private mutating func openPick() {
        phase = .pickingCards(drawCards())
    }

    /// Opens a card pick when `thresholds` were crossed this tick, unless those kills also emptied a fully
    /// issued level (then the pick is skipped, nectar carries over and step 12 clears). Returns whether the
    /// tick must end here.
    mutating func openPickUnlessClearing(thresholds: Int, events: inout [GameEvent]) -> Bool {
        guard thresholds > 0, !(director.allSpawnsIssued && mobs.isEmpty) else { return false }
        pendingPicks = thresholds - 1
        openPick()
        events.append(.nectarThreshold)
        return true
    }

    /// The single kill-bookkeeping site: marks `mobs[m]` dead, reports the kill and banks its nectar,
    /// counting any crossed threshold into `thresholds`.
    mutating func registerKill(_ m: Int, deadIDs: inout Set<Int>, thresholds: inout Int, events: inout [GameEvent]) {
        deadIDs.insert(mobs[m].id)
        events.append(.mobKilled(id: mobs[m].id, type: mobs[m].type, at: mobs[m].position))
        if nectar.add(mobs[m].type.stats.nectar) { thresholds += 1 }
    }

    /// Every damage path goes through here: flat armor reduction, minimum 1 per hit.
    func damage(_ raw: Double, to mob: inout Mob) {
        mob.hp -= max(1, raw - mob.type.stats.armor)
    }

    mutating func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func nearestMob() -> Mob? {
        mobs.min { $0.position.length < $1.position.length }
    }

    private mutating func fireVolley(at target: Vec2, events: inout [GameEvent]) {
        let stats = hive.stats
        let base = atan2(target.y, target.x)
        let n = stats.projectileCount
        for i in 0..<n {
            let angle = base + (Double(i) - Double(n - 1) / 2) * World.spreadRadians
            let p = Projectile(id: makeID(), position: .zero,
                               velocity: Vec2(cos(angle), sin(angle)) * stats.projectileSpeed,
                               damage: stats.damage, pierceRemaining: stats.pierce)
            projectiles.append(p)
            events.append(.projectileFired(id: p.id))
        }
    }

    #if DEBUG
    /// DEBUG-only stress hook for the app: spawns `count` mobs evenly spaced around the spawn radius at the
    /// current wave's hp scale. Uses the id counter only (no rng), so it never perturbs the seeded stream.
    public mutating func debugSpawnRing(type: MobType, count: Int) {
        guard count > 0 else { return }
        let hpScale = director.currentHpScale
        for k in 0..<count {
            let angle = Double(k) / Double(count) * 2 * .pi
            mobs.append(Mob(id: makeID(), type: type,
                            position: Vec2(cos(angle), sin(angle)) * World.spawnRadius, hpScale: hpScale))
        }
    }

    /// DEBUG-only start-HP hook for the app (`HIVE_START_HP`): sets the hive's hp, clamped to `maxHP`. `0` downs
    /// the hive on the first ticking frame, since step (9) tests `hive.hp <= 0` unconditionally. Touches no rng.
    public mutating func debugSetHiveHP(_ hp: Double) {
        hive.hp = min(hp, hive.stats.maxHP)
    }
    #endif

    // MARK: - Test hooks (internal; reachable via @testable)

    mutating func debugApplyCard(_ card: UpgradeCard) {
        apply(card: card)
    }

    mutating func debugSetMob(index: Int, position: Vec2, hp: Double) {
        mobs[index].position = position
        mobs[index].hp = hp
    }

    mutating func debugAddMob(type: MobType, position: Vec2) {
        mobs.append(Mob(id: makeID(), type: type, position: position))
    }

    mutating func debugAddProjectile(at position: Vec2, velocity: Vec2, damage: Double) {
        projectiles.append(Projectile(id: makeID(), position: position, velocity: velocity,
                                      damage: damage, pierceRemaining: hive.stats.pierce))
    }
}
