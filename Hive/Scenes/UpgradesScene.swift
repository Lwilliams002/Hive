import SpriteKit
import HiveCore

/// Permanent upgrades: a live hive preview on top and one row per track below.
final class UpgradesScene: SKScene {
    private unowned let flow: AppFlow
    private let back = Button(title: "BACK", name: "back", size: CGSize(width: 100, height: 40), style: .outlined)
    private let balance = SKLabelNode(fontNamed: Typography.font)
    private let tierLabel = SKLabelNode(fontNamed: Typography.font)
    private var hive: SKNode?
    private var rows = SKNode()
    private var buyButtons: [(track: UpgradeTrack, button: Button)] = []
    private var shownTier = 1
    private var didLeave = false
    private var homeX: CGFloat { size.width / 2 - 24 }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    init(flow: AppFlow, size: CGSize) {
        self.flow = flow
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
        removeAllChildren()
        didLeave = false
        let w = size.width
        let h = size.height

        back.position = CGPoint(x: -w / 2 + 70, y: h / 2 - 60)
        addChild(back)

        balance.fontSize = 16
        balance.fontColor = Palette.gold
        balance.horizontalAlignmentMode = .right
        balance.verticalAlignmentMode = .center
        balance.position = CGPoint(x: homeX, y: h / 2 - 60)
        addChild(balance)

        tierLabel.fontSize = 12
        tierLabel.fontColor = Palette.gold
        tierLabel.alpha = 0.7
        tierLabel.verticalAlignmentMode = .center
        tierLabel.position = CGPoint(x: 0, y: h / 2 - 190 - 104)
        addChild(tierLabel)

        shownTier = flow.state.upgrades.visualTier
        rebuildHive()
        refresh()
    }

    private func rebuildHive() {
        hive?.removeFromParent()
        let node = HiveRenderer.makeHive(visualTier: flow.state.upgrades.visualTier)
        node.position = CGPoint(x: 0, y: size.height / 2 - 190)
        addChild(node)
        hive = node
    }

    private func refresh() {
        let state = flow.state
        let coins = state.coins
        balance.text = "\u{25C6} " + (Self.formatter.string(from: NSNumber(value: coins)) ?? "\(coins)")

        let up = state.upgrades
        let v = up.visualTier
        var text = "TIER \(v) / \(HiveRenderer.maxTier)"
        if v < HiveRenderer.maxTier {
            let n = 5 - up.totalTiers % 5
            text += " \u{00B7} next look at \(n) more tier\(n == 1 ? "" : "s")"
        }
        tierLabel.text = text

        rows.removeFromParent()
        rows = SKNode()
        buyButtons = []
        let h = size.height
        let topEdge = max(h / 2 - 440, -h / 2 + 56 + 5 * 64 + 4 * 10)
        for (i, track) in UpgradeTrack.allCases.enumerated() {
            let row = makeRow(track: track, state: state)
            row.position = CGPoint(x: 0, y: topEdge - 32 - CGFloat(i) * 74)
            rows.addChild(row)
            let pos = CGPoint(x: 126, y: row.position.y)
            let size = CGSize(width: 96, height: 36)
            if let cost = state.upgrades.nextCost(for: track) {
                let b = Button(title: "\u{25C6} " + (Self.formatter.string(from: NSNumber(value: cost)) ?? "\(cost)"), name: "buy:\(track.rawValue)", size: size, style: .filled)
                b.isEnabled = state.canAfford(track)
                b.position = pos
                rows.addChild(b)
                buyButtons.append((track, b))
            } else {
                let b = Button(title: "MAX", name: "buy:\(track.rawValue)", size: size, style: .outlined)
                b.isEnabled = false
                b.position = pos
                rows.addChild(b)
            }
        }
        addChild(rows)
    }

    private func makeRow(track: UpgradeTrack, state: GameState) -> SKNode {
        let row = SKNode()
        let bg = SKShapeNode(path: Shapes.roundedRect(CGSize(width: 360, height: 64), corner: 12))
        bg.fillColor = UIColor(red: 0x15 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)
        bg.strokeColor = Palette.amber.withAlphaComponent(0.4)
        bg.lineWidth = 1
        row.addChild(bg)

        func label(_ text: String, size: CGFloat, color: UIColor, alpha: CGFloat, y: CGFloat) {
            let l = SKLabelNode(fontNamed: Typography.font)
            l.text = text
            l.fontSize = size
            l.fontColor = color
            l.alpha = alpha
            l.horizontalAlignmentMode = .left
            l.verticalAlignmentMode = .center
            l.position = CGPoint(x: -160, y: y)
            row.addChild(l)
        }
        let tier = state.upgrades.tier(of: track)
        label(track.displayName, size: 16, color: Palette.white, alpha: 1, y: 18)
        label(track.summary, size: 11, color: Palette.gold, alpha: 0.7, y: 2)
        let next = tier >= PermanentUpgrades.maxTier
            ? "Maxed"
            : state.upgrades.effectDescription(for: track, atTier: tier + 1)
        label(next, size: 11, color: Palette.white, alpha: 0.55, y: -14)

        for i in 0..<PermanentUpgrades.maxTier {
            let pip = SKShapeNode(path: Shapes.roundedRect(CGSize(width: 9, height: 9), corner: 2))
            pip.position = CGPoint(x: -34 + CGFloat(i) * 11 + 4.5, y: 18)
            if i < tier {
                pip.fillColor = Palette.gold
                pip.strokeColor = .clear
            } else {
                pip.fillColor = .clear
                pip.strokeColor = Palette.burntOrange.withAlphaComponent(0.8)
                pip.lineWidth = 1
            }
            row.addChild(pip)
        }
        return row
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !didLeave, let touch = touches.first else { return }
        let p = touch.location(in: self)
        if back.contains(p) {
            didLeave = true
            flow.showHome()
            return
        }
        guard let hit = buyButtons.first(where: {
            abs(p.x - $0.button.position.x) <= 48 && abs(p.y - $0.button.position.y) <= 18
        }) else { return }
        if flow.state.canAfford(hit.track), flow.purchase(hit.track) {
            let newTier = flow.state.upgrades.visualTier
            refresh()
            if newTier != shownTier {
                shownTier = newTier
                rebuildHive()
                hive?.run(.sequence([
                    .scale(to: 1.12, duration: 0.12),
                    .scale(to: 1.0, duration: 0.13),
                ]))
            }
        } else {
            shakeBalance()
        }
    }

    private func shakeBalance() {
        balance.removeAllActions()
        balance.position.x = homeX
        let step = SKAction.sequence([
            .moveTo(x: homeX + 6, duration: 0.0333), .moveTo(x: homeX - 6, duration: 0.0333),
        ])
        balance.run(.sequence([.repeat(step, count: 3), .moveTo(x: homeX, duration: 0.0333)]))
    }
}
