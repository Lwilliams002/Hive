import Foundation

// The mechanics `tick` delegates to: boss escorts (3b), splash (6) and guard bees (10b). Bodies moved verbatim
// from `World.swift` (M4 Task 2); every kill goes through `registerKill` and every pick opens through
// `openPickUnlessClearing`, so the rng consumption and floating-point order of the tick are unchanged.
extension World {
    // MARK: - Escorts

    /// Step (3b): counts down every escort timer and spawns the escorts owed this tick.
    mutating func tickEscorts(dt: Double, events: inout [GameEvent]) {
        for i in 0..<mobs.count {
            guard let escort = mobs[i].type.stats.escort else { continue }
            precondition(escort.every > 0, "escort interval must be positive")
            mobs[i].escortTimer -= dt
            while mobs[i].escortTimer <= 0 {
                spawnEscort(escort, parentIndex: i, events: &events)
                mobs[i].escortTimer += escort.every
            }
        }
    }

    /// Spawns `escort.count` mobs on the parent's bearing from the hive (each with its own ±15° jitter) at
    /// `max(parent distance, escortMinDistance)`, so a boss parked at the hive edge never spawns escorts inside
    /// contact range. Escorts inherit the parent's `hpScale`.
    private mutating func spawnEscort(_ escort: EscortSpawn, parentIndex i: Int, events: inout [GameEvent]) {
        let parent = mobs[i]
        let bearing = atan2(parent.position.y, parent.position.x)
        let distance = max(parent.position.length, World.escortMinDistance)
        var ids: [Int] = []
        for _ in 0..<escort.count {
            let angle = bearing + (rng.unitDouble() * 2 - 1) * World.escortJitterRadians
            let mob = Mob(id: makeID(), type: escort.type, position: Vec2(cos(angle), sin(angle)) * distance,
                          hpScale: parent.hpScale)
            mobs.append(mob)
            ids.append(mob.id)
            events.append(.mobSpawned(id: mob.id, type: mob.type))
        }
        events.append(.escortSpawned(parentID: parent.id, ids: ids))
    }

    // MARK: - Splash

    /// Splash: other alive mobs near the hit mob `mobs[m]` take a fraction of the raw damage (never chains).
    mutating func applySplash(from m: Int, raw: Double, deadIDs: inout Set<Int>, thresholds: inout Int,
                              events: inout [GameEvent]) {
        guard modifiers.splashRadius > 0 && modifiers.splashFraction > 0 else { return }
        let center = mobs[m].position
        for n in mobs.indices where n != m && !deadIDs.contains(mobs[n].id) {
            guard mobs[n].position.distance(to: center) < modifiers.splashRadius else { continue }
            // Armor can absorb the whole splash; such a graze neither flashes nor reports a hit.
            guard splashDamage(raw * modifiers.splashFraction, to: &mobs[n]) > 0 else { continue }
            mobs[n].hitFlash = World.hitFlashDuration
            events.append(.mobHit(id: mobs[n].id))
            if mobs[n].hp <= 0 {
                registerKill(n, deadIDs: &deadIDs, thresholds: &thresholds, events: &events)
            }
        }
    }

    /// Splash damage to a neighbor: flat armor reduction with no minimum (armor can absorb it entirely).
    /// Applies splash damage reduced by armor and returns the amount actually dealt (0 when fully absorbed).
    @discardableResult
    private func splashDamage(_ raw: Double, to mob: inout Mob) -> Double {
        let applied = max(0, raw - mob.type.stats.armor)
        mob.hp -= applied
        return applied
    }

    // MARK: - Guard bees

    /// Step (10b): each bee hits a touching mob at most every `GuardBee.hitCooldown` seconds; mobs killed here
    /// are removed. Returns true when those kills opened a card pick, so the caller ends the tick.
    mutating func tickBees(dt: Double, events: inout [GameEvent]) -> Bool {
        guard !bees.isEmpty else { return false }
        let positions = beePositions
        var beeKills = Set<Int>()
        var beeThresholds = 0
        for b in bees.indices {
            // Decay cooldowns; expired entries are dropped (absent ≡ ready), which also forgets removed mobs.
            bees[b].cooldowns = bees[b].cooldowns.compactMapValues { $0 - dt > 0 ? $0 - dt : nil }
            for m in mobs.indices where !beeKills.contains(mobs[m].id) {
                let reach = mobs[m].type.stats.radius + GuardBee.touchRadius
                guard positions[b].distance(to: mobs[m].position) < reach,
                      bees[b].cooldowns[mobs[m].id, default: 0] <= 0 else { continue }
                damage(modifiers.beeDamage, to: &mobs[m])
                mobs[m].hitFlash = World.hitFlashDuration
                bees[b].cooldowns[mobs[m].id] = GuardBee.hitCooldown
                events.append(.beeHit(mobID: mobs[m].id))
                if mobs[m].hp <= 0 {
                    registerKill(m, deadIDs: &beeKills, thresholds: &beeThresholds, events: &events)
                }
            }
        }
        mobs.removeAll { beeKills.contains($0.id) }
        countClearedWave()
        // Same rule as step 6: pause into a pick unless these kills emptied the level.
        return openPickUnlessClearing(thresholds: beeThresholds, events: &events)
    }

    /// Current bee positions: bee `k` of `n` at angle `2.4 · time + 2πk/n` on the 72-pt orbit.
    public var beePositions: [Vec2] {
        let n = bees.count
        let base = GuardBee.angularSpeed * time
        return (0..<n).map { k in
            let angle = base + 2 * .pi * Double(k) / Double(n)
            return Vec2(cos(angle), sin(angle)) * GuardBee.orbitRadius
        }
    }
}
