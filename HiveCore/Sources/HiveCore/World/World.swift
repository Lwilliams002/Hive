import Foundation

public struct World {
    public private(set) var hive: Hive
    public private(set) var mobs: [Mob] = []
    public private(set) var projectiles: [Projectile] = []
    public private(set) var director: WaveDirector
    public private(set) var phase: RunPhase = .playing
    public private(set) var time: Double = 0
    public private(set) var nectar = NectarMeter()

    public static let spawnRadius: Double = 520

    private let level: LevelDefinition
    private var rng: SeededRNG
    /// Shared id counter for mobs and projectiles.
    private var nextID = 1
    /// Waves announced via `waveStarted` so far.
    private var wavesStarted = 0
    /// Spawns still owed by the current wave before the next director spawn means a new wave.
    private var spawnsLeftInWave = 0

    private static let hitFlashDuration = 0.08
    /// Seconds between hits from a boss parked at the hive edge.
    private static let bossAttackInterval = 1.0
    private static let spreadRadians = 10.0 * .pi / 180

    public init(level: LevelDefinition, hiveStats: HiveStats = .base, seed: UInt64) {
        self.level = level
        self.director = WaveDirector(level: level)
        self.hive = Hive(stats: hiveStats, hp: hiveStats.maxHP, cooldown: 0)
        self.rng = SeededRNG(seed: seed)
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
            if spawnsLeftInWave <= 0 && wavesStarted < level.waves.count {
                let wave = level.waves[wavesStarted]
                wavesStarted += 1
                spawnsLeftInWave = wave.spawns.reduce(0) { $0 + $1.count }
                events.append(.waveStarted(number: wavesStarted, isBoss: wave.isBoss))
            }
            spawnsLeftInWave -= spawns.count
            for type in spawns {
                let angle = rng.unitDouble() * 2 * .pi
                let mob = Mob(id: makeID(), type: type,
                              position: Vec2(cos(angle), sin(angle)) * World.spawnRadius)
                mobs.append(mob)
                events.append(.mobSpawned(id: mob.id, type: type))
            }
        }

        // (4) move mobs toward origin; newly spawned mobs skip movement on their spawn tick so they start exactly on the spawn radius.
        // Bosses stop at the hive edge (Hive.radius + their radius) instead of overlapping it.
        for i in 0..<preexistingMobCount {
            let pos = mobs[i].position
            let stats = mobs[i].type.stats
            let step = stats.speed * dt
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
        var thresholdCrossed = false
        for p in projectiles.indices {
            for m in mobs.indices {
                let mob = mobs[m]
                if deadIDs.contains(mob.id) || projectiles[p].hitMobIDs.contains(mob.id) { continue }
                let reach = mob.type.stats.radius + Projectile.radius
                guard projectiles[p].position.distance(to: mob.position) < reach else { continue }
                mobs[m].hp -= projectiles[p].damage
                mobs[m].hitFlash = World.hitFlashDuration
                projectiles[p].hitMobIDs.append(mob.id)
                events.append(.mobHit(id: mob.id))
                if mobs[m].hp <= 0 {
                    deadIDs.insert(mob.id)
                    events.append(.mobKilled(id: mob.id, type: mob.type, at: mobs[m].position))
                    if nectar.add(mob.type.stats.nectar) { thresholdCrossed = true }
                }
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

        // Nectar threshold: pause into card pick, skipping the rest of the tick.
        if thresholdCrossed {
            phase = .pickingCards(UpgradeCatalog.draw(count: 3, from: UpgradeCatalog.milestone1, rng: &rng))
            events.append(.nectarThreshold)
            return events
        }

        // (8) mob–hive contact. Non-boss mobs deal contact damage once and are removed.
        // Bosses parked at the hive edge stay alive and hit once on arrival, then every `bossAttackInterval` seconds.
        var contacted = Set<Int>()
        for i in mobs.indices {
            let stats = mobs[i].type.stats
            let edge = Hive.radius + stats.radius
            let dist = mobs[i].position.length
            if stats.isBoss {
                guard dist <= edge + 1e-6 else { continue }
                mobs[i].attackCooldown -= dt
                if mobs[i].attackCooldown <= 0 {
                    hive.hp -= stats.contactDamage
                    events.append(.hiveDamaged(amount: stats.contactDamage, hp: hive.hp))
                    mobs[i].attackCooldown += World.bossAttackInterval
                }
            } else if dist < edge {
                hive.hp -= stats.contactDamage
                events.append(.hiveDamaged(amount: stats.contactDamage, hp: hive.hp))
                contacted.insert(mobs[i].id)
            }
        }
        mobs.removeAll { contacted.contains($0.id) }

        // (9) game over
        if hive.hp <= 0 {
            phase = .gameOver
            events.append(.gameOver)
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

        // (11) decay hit flash
        for i in mobs.indices {
            mobs[i].hitFlash = max(0, mobs[i].hitFlash - dt)
        }

        // (12) cleared
        if phase == .playing && director.allSpawnsIssued && mobs.isEmpty {
            phase = .cleared
            events.append(.levelCleared)
        }
        return events
    }

    /// Applies the chosen card and resumes play. No-op outside `.pickingCards`.
    public mutating func choose(_ card: UpgradeCard) {
        guard case .pickingCards = phase else { return }
        var stats = hive.stats
        stats.apply(card.effect, to: &hive)
        hive.stats = stats
        phase = .playing
    }

    // MARK: - Helpers

    private mutating func makeID() -> Int {
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

    // MARK: - Test hooks (internal; reachable via @testable)

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
