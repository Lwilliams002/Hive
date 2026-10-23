import SpriteKit

/// Home screen: coin balance, the hive at its current visual tier, and navigation buttons.
final class HomeScene: SKScene {
    private unowned let flow: AppFlow
    private let play = Button(title: "PLAY", name: "play", style: .filled)
    private let levels = Button(title: "LEVELS", name: "levels", style: .outlined)
    private let upgrades = Button(title: "UPGRADES", name: "upgrades", style: .outlined)
    private let endless = Button(title: "ENDLESS", name: "endless", style: .outlined)
    private var didStart = false

    init(flow: AppFlow, size: CGSize) {
        self.flow = flow
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
        removeAllChildren()
        didStart = false

        let w = size.width
        let h = size.height

        let title = SKLabelNode(fontNamed: Typography.font)
        title.attributedText = NSAttributedString(string: "HIVE", attributes: [
            .font: UIFont(name: Typography.font, size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: Palette.gold,
            .kern: 4,
        ])
        title.verticalAlignmentMode = .center
        title.alpha = 0.5
        title.position = CGPoint(x: 0, y: h / 2 - 68)
        addChild(title)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let coins = formatter.string(from: NSNumber(value: flow.state.coins)) ?? "\(flow.state.coins)"
        let balance = SKLabelNode(fontNamed: Typography.font)
        balance.text = "\u{25C6} \(coins)"
        balance.fontSize = 16
        balance.fontColor = Palette.gold
        balance.horizontalAlignmentMode = .left
        balance.verticalAlignmentMode = .center
        balance.position = CGPoint(x: -w / 2 + 24, y: h / 2 - 52)
        addChild(balance)

        var tier = flow.state.upgrades.visualTier
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["HIVE_PREVIEW_TIER"], let t = Int(raw) { tier = t }
        #endif
        let hive = HiveRenderer.makeHive(visualTier: tier)
        hive.position = CGPoint(x: 0, y: h * 0.14)
        // Grow small hives up to 1.9×, but keep the drawn structure within 170 pt of the centre, so on-screen
        // size never shrinks as the tier rises (tier 11 ≈ 340 pt wide).
        let combRadius = HiveRenderer.combRadius(visualTier: tier)
        let scale = max(1, min(1.9, 170 / combRadius))
        hive.setScale(scale)
        hive.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 240)))
        addChild(hive)

        let level = SKLabelNode(fontNamed: Typography.font)
        level.text = flow.allLevelsCleared ? "ALL LEVELS CLEARED" : "LEVEL \(flow.playableLevel)"
        level.fontSize = 14
        level.fontColor = Palette.gold
        level.alpha = 0.8
        level.verticalAlignmentMode = .center
        level.position = CGPoint(x: 0, y: h * 0.14 - (combRadius * scale + 28))
        addChild(level)

        play.isEnabled = !flow.levels.availableLevelIDs().isEmpty
        endless.isEnabled = flow.state.endlessUnlocked
        let pitch: CGFloat = 52 + 16
        // Keep at least 20 pt between the level label's centre and PLAY's top edge on shorter screens.
        var y = min(-h * 0.12, level.position.y - 20 - 26)
        for button in [play, levels, upgrades, endless] {
            button.position = CGPoint(x: 0, y: y)
            addChild(button)
            y -= pitch
        }

        let sub = SKLabelNode(fontNamed: Typography.font)
        if !flow.state.endlessUnlocked {
            sub.text = "Unlocks after level 10"
        } else if flow.state.bestEndlessWave > 0 {
            let best = flow.state.bestEndlessWave
            sub.text = "Best: \(best) \(best == 1 ? "wave" : "waves")"
        } else {
            sub.text = "Survive as long as you can"
        }
        sub.fontSize = 11
        sub.fontColor = Palette.white
        sub.alpha = 0.6
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: endless.position.y - 26 - 14)
        addChild(sub)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !didStart, let touch = touches.first else { return }
        let p = touch.location(in: self)
        if play.contains(p) {
            guard !flow.levels.availableLevelIDs().isEmpty else { return }
            didStart = true
            flow.startLevel(id: flow.playableLevel)
        } else if levels.contains(p) {
            didStart = true
            flow.showLevelSelect()
        } else if endless.isEnabled && endless.contains(p) {
            didStart = true
            flow.startEndless()
        } else if upgrades.contains(p) {
            didStart = true
            flow.showUpgrades()
        }
    }
}
