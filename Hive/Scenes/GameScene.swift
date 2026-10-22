import SpriteKit
import HiveCore

final class GameScene: SKScene {
    private var world: World!
    private var mobNodes: [Int: MobNode] = [:]
    private var projectileNodes: [Int: ProjectileNode] = [:]
    private var lastUpdate: TimeInterval?

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background

        let level: LevelDefinition
        do {
            guard let url = Bundle.main.url(forResource: "level_001", withExtension: "json", subdirectory: "Levels") else {
                throw CocoaError(.fileNoSuchFile)
            }
            level = try LevelDefinition.load(from: Data(contentsOf: url))
        } catch {
            fatalError("Failed to load level_001.json: \(error)")
        }
        world = World(level: level, seed: UInt64(Date().timeIntervalSince1970))
        addChild(HiveNode(tier: 1))
    }

    override func update(_ currentTime: TimeInterval) {
        guard world != nil else { return }
        let dt: Double
        if let last = lastUpdate {
            dt = min(currentTime - last, 1.0 / 30)
        } else {
            dt = 0
        }
        lastUpdate = currentTime

        for event in world.tick(dt: dt) {
            switch event {
            case .levelCleared: print("levelCleared")
            case .gameOver: print("gameOver")
            default: break
            }
        }
        reconcile()
    }

    private func reconcile() {
        var liveMobs = Set<Int>()
        for mob in world.mobs {
            liveMobs.insert(mob.id)
            let node: MobNode
            if let existing = mobNodes[mob.id] {
                node = existing
            } else {
                node = MobNode(type: mob.type)
                node.zPosition = 1
                addChild(node)
                mobNodes[mob.id] = node
            }
            let x = CGFloat(mob.position.x), y = CGFloat(mob.position.y)
            node.position = CGPoint(x: x, y: y)
            node.zRotation = atan2(-y, -x)
            node.setHitFlash(mob.hitFlash > 0)
        }
        for (id, node) in mobNodes where !liveMobs.contains(id) {
            node.removeFromParent()
            mobNodes[id] = nil
        }

        var liveProjectiles = Set<Int>()
        for p in world.projectiles {
            liveProjectiles.insert(p.id)
            let node: ProjectileNode
            if let existing = projectileNodes[p.id] {
                node = existing
            } else {
                node = ProjectileNode()
                node.zPosition = 2
                addChild(node)
                projectileNodes[p.id] = node
            }
            node.position = CGPoint(x: p.position.x, y: p.position.y)
        }
        for (id, node) in projectileNodes where !liveProjectiles.contains(id) {
            node.removeFromParent()
            projectileNodes[id] = nil
        }
    }
}
