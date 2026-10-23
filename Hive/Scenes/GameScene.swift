import SpriteKit
import UIKit
import HiveCore

/// Modal layer shown above play; the scene forwards touches to it in its own coordinate space.
protocol Overlay: SKNode {
    var zPosition: CGFloat { get set }
    func handleTouch(at point: CGPoint)
}

extension CardPickOverlay: Overlay {}
extension EndOverlay: Overlay {}
extension PauseOverlay: Overlay {}

final class GameScene: SKScene {
    private unowned let flow: AppFlow
    private let level: LevelDefinition
    private let levelId: Int
    private let stats: HiveStats
    private let cardPool: [UpgradeCard]
    private let startingCardPool: [UpgradeCard]
    private let startingCardCount: Int
    /// The run whose result has already been reported; guards against double-recording.
    private var lastReportedRunID: UUID?

    private var world: World!
    private var mobNodes: [Int: MobNode] = [:]
    private var projectileNodes: [Int: ProjectileNode] = [:]
    private var beeNodes: [GuardBeeNode] = []
    private var slowField: SlowFieldNode?
    /// Mobs hit by a guard bee this frame; flashed even if the core's flash timer already ran out.
    private var beeHitMobs = Set<Int>()
    private var lastUpdate: TimeInterval?
    private var hud: HUDNode!
    private var startingBanner: SKNode?
    private var bossBanner: SKNode?
    private var overlay: Overlay?
    /// Game-level pause (distinct from `SKNode.isPaused`, which would also stop overlay rendering/actions).
    private var isGamePaused = false

    init(level: LevelDefinition, levelId: Int, stats: HiveStats, cardPool: [UpgradeCard],
         startingCardPool: [UpgradeCard], startingCardCount: Int, flow: AppFlow, size: CGSize) {
        self.level = level
        self.levelId = levelId
        self.stats = stats
        self.cardPool = cardPool
        self.startingCardPool = startingCardPool
        self.startingCardCount = startingCardCount
        self.flow = flow
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background

        if hud == nil {
            let tier = flow.state.upgrades.visualTier
            let hive = HiveRenderer.makeHive(visualTier: tier)
            // Keep the drawn comb within a few points of the contact radius (the glow may overhang).
            hive.setScale(min(1, (CGFloat(Hive.radius) + 4) / HiveRenderer.combRadius(visualTier: tier)))
            addChild(hive)
            hud = HUDNode(viewSize: size)
            addChild(hud)
            startRun()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillResignActive() {
        pauseGame()
    }

    /// Pauses play and shows the pause overlay; no-op unless playing with no overlay up.
    private func pauseGame() {
        guard world != nil, world.phase == .playing, overlay == nil, !isGamePaused else { return }
        isGamePaused = true
        let o = PauseOverlay(viewSize: size, onResume: { [weak self] in
            guard let self = self else { return }
            self.isGamePaused = false
            self.overlay = nil
            self.lastUpdate = nil
        }, onRetry: { [weak self] in
            self?.startRun()
        }, onHome: { [weak self] in
            self?.abandonRunAndGoHome()
        })
        overlay = o
        addChild(o)
    }

    /// Leaves an unfinished run from the pause menu: pays it out as a loss (once per run), then goes home.
    private func abandonRunAndGoHome() {
        let inProgress: Bool
        switch world.phase {
        case .playing, .pickingCards: inProgress = true
        case .cleared, .gameOver: inProgress = false
        }
        if inProgress && lastReportedRunID != world.runID {
            lastReportedRunID = world.runID
            flow.runEnded(flow.makeRunResult(world: world, levelId: levelId))
        }
        flow.showHome()
    }

    private func startRun() {
        for node in mobNodes.values { node.removeFromParent() }
        for node in projectileNodes.values { node.removeFromParent() }
        for node in beeNodes { node.removeFromParent() }
        mobNodes.removeAll()
        projectileNodes.removeAll()
        beeNodes.removeAll()
        slowField?.removeFromParent()
        slowField = nil
        bossBanner?.removeFromParent()
        bossBanner = nil
        beeHitMobs.removeAll()
        overlay?.removeFromParent()
        overlay = nil
        isGamePaused = false
        world = World(level: level, hiveStats: stats, cardPool: cardPool,
                      startingCardCount: startingCardCount, startingCardPool: startingCardPool,
                      seed: UInt64(Date().timeIntervalSince1970 * 1000))
        lastUpdate = nil
        showStartingCards(world.startingCards)
    }

    /// Briefly names the queen's starting cards: shown 1.2 s, then a 0.3 s fade.
    private func showStartingCards(_ cards: [UpgradeCard]) {
        startingBanner?.removeFromParent()
        startingBanner = nil
        guard !cards.isEmpty else { return }
        let banner = SKNode()
        banner.position = CGPoint(x: 0, y: size.height / 4)
        banner.zPosition = 90

        let caption = SKLabelNode(fontNamed: Typography.font)
        caption.text = "STARTING CARDS"
        caption.fontSize = 11
        caption.fontColor = Palette.gold
        caption.alpha = 0.7
        caption.verticalAlignmentMode = .center
        caption.position = CGPoint(x: 0, y: 12)
        banner.addChild(caption)

        let names = SKLabelNode(fontNamed: Typography.font)
        names.text = cards.map(\.name).joined(separator: " \u{00B7} ")
        names.fontSize = 15
        names.fontColor = Palette.white
        names.verticalAlignmentMode = .center
        names.position = CGPoint(x: 0, y: -8)
        banner.addChild(names)

        banner.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        addChild(banner)
        startingBanner = banner
    }

    /// Names the boss of the wave that just started: shown 2 s, then a 0.3 s fade.
    private func showBossBanner() {
        guard let wave = world.director.currentWaveDefinition,
              let type = wave.spawns.first(where: { $0.type.stats.isBoss })?.type,
              let text = BossBanner.text(for: type) else { return }
        bossBanner?.removeFromParent()
        let banner = BossBanner(title: text.title, subtitle: text.subtitle, viewSize: size)
        banner.run(.sequence([.wait(forDuration: 2.0), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        addChild(banner)
        bossBanner = banner
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if let overlay = overlay {
            overlay.handleTouch(at: touch.location(in: overlay))
            return
        }
        guard let hud = hud else { return }
        for hit in hud.nodes(at: touch.location(in: hud)) {
            var node: SKNode? = hit
            while let n = node {
                if n.name == "pause" {
                    pauseGame()
                    return
                }
                node = n.parent
            }
        }
    }

    private func presentOverlayIfNeeded() {
        guard overlay == nil else { return }
        switch world.phase {
        case .playing:
            break
        case .pickingCards(let cards):
            let o = CardPickOverlay(cards: cards, viewSize: size) { [weak self] card in
                guard let self = self else { return }
                self.world.choose(card)
                self.overlay = nil
            }
            overlay = o
            addChild(o)
        case .cleared, .gameOver:
            guard lastReportedRunID != world.runID else { return }
            lastReportedRunID = world.runID
            let result = flow.makeRunResult(world: world, levelId: levelId)
            flow.runEnded(result)
            let nextId = levelId + 1
            let hasNext = flow.levels.availableLevelIDs().contains(nextId)
            let onContinue: (() -> Void)? = hasNext ? { [weak self] in self?.flow.startLevel(id: nextId) } : nil
            let o = EndOverlay(result: result, viewSize: size, onContinue: onContinue,
                               onRetry: { [weak self] in self?.startRun() },
                               onHome: { [weak self] in self?.flow.showHome() })
            overlay = o
            addChild(o)
        }
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

        beeHitMobs.removeAll()
        if !isGamePaused {
            for event in world.tick(dt: dt) {
                switch event {
                case .waveStarted(_, let isBoss) where isBoss:
                    showBossBanner()
                case .beeHit(let mobID):
                    beeHitMobs.insert(mobID)
                default:
                    break
                }
            }
        }
        reconcile()
        hud.update(hp: world.hive.hp, maxHP: world.hive.stats.maxHP,
                   wave: world.director.waveNumber, totalWaves: world.director.totalWaves,
                   isBoss: world.director.isBossWave,
                   nectar: world.nectar.current, nectarThreshold: world.nectar.threshold,
                   coinsPending: CoinRules.coins(levelId: levelId,
                                                 wavesCleared: max(0, world.director.waveNumber - 1),
                                                 cleared: false,
                                                 multiplier: flow.state.upgrades.coinMultiplier))
        presentOverlayIfNeeded()
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
            node.setHitFlash(mob.hitFlash > 0 || beeHitMobs.contains(mob.id))
        }
        for (id, node) in mobNodes where !liveMobs.contains(id) {
            node.removeFromParent()
            mobNodes[id] = nil
        }

        let beePositions = world.beePositions
        while beeNodes.count < beePositions.count {
            let node = GuardBeeNode()
            node.zPosition = 2
            addChild(node)
            beeNodes.append(node)
        }
        while beeNodes.count > beePositions.count {
            beeNodes.removeLast().removeFromParent()
        }
        for (node, p) in zip(beeNodes, beePositions) {
            node.position = CGPoint(x: p.x, y: p.y)
        }

        let slowRadius = CGFloat(world.modifiers.slowRadius)
        if slowRadius > 0 {
            if slowField?.radius != slowRadius {
                slowField?.removeFromParent()
                let field = SlowFieldNode(radius: slowRadius)
                field.zPosition = -3  // beneath the hive (glow is -2)
                addChild(field)
                slowField = field
            }
        } else if let field = slowField {
            field.removeFromParent()
            slowField = nil
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
