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
    /// Time of the last purchase; buy taps within `buyDebounce` of it are ignored.
    private var lastPurchaseTime: TimeInterval = -.infinity
    private static let buyDebounce: TimeInterval = 0.25
    private var homeX: CGFloat { size.width / 2 - 24 }

    // Layout, computed top-down from constraints (see `layout()`).
    private static let rowHeight: CGFloat = 64
    private static let rowGap: CGFloat = 10
    private static let rowsBottomInset: CGFloat = 56
    private static let tierLabelGap: CGFloat = 16
    /// Bottom of the BACK / balance bar, measured down from the top edge.
    private static let topBarInset: CGFloat = 84
    private var rowsTop: CGFloat = 0
    private var hiveCenterY: CGFloat = 0
    private var hiveScale: CGFloat = 1

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
        tierLabel.verticalAlignmentMode = .bottom
        addChild(tierLabel)
        layout()

        shownTier = flow.state.upgrades.visualTier
        rebuildHive()
        refresh()
    }

    private func rebuildHive() {
        hive?.removeFromParent()
        let node = HiveRenderer.makeHive(visualTier: flow.state.upgrades.visualTier)
        node.position = CGPoint(x: 0, y: hiveCenterY)
        node.setScale(hiveScale)
        addChild(node)
        hive = node
    }

    /// Rows block bottom-anchored; tier label just above it; the hive preview centred in the space between
    /// the tier label and the top bar, scaled so the largest (tier-11) hive plus some glow always fits.
    private func layout() {
        let h = size.height
        let rowsHeight = 5 * Self.rowHeight + 4 * Self.rowGap
        rowsTop = -h / 2 + Self.rowsBottomInset + rowsHeight
        tierLabel.position = CGPoint(x: 0, y: rowsTop + Self.tierLabelGap)
        // Measure with sample text: the label's height does not depend on its content.
        tierLabel.text = "TIER 1"
        let labelTop = tierLabel.frame.maxY
        let barBottom = h / 2 - Self.topBarInset
        let space = barBottom - labelTop
        hiveCenterY = (barBottom + labelTop) / 2
        let needed = 2 * HiveRenderer.combRadius(visualTier: HiveRenderer.maxTier) + 40
        hiveScale = max(0.1, min(1, (space - 24) / needed))
    }

    private func refresh() {
        let state = flow.state
        let coins = state.coins
        balance.text = "\u{25C6} " + (Self.formatter.string(from: NSNumber(value: coins)) ?? "\(coins)")

        let up = state.upgrades
        let v = up.visualTier
        var text = "TIER \(v) / \(HiveRenderer.maxTier)"
        let n = up.tiersToNextLook
        if n > 0 {
            text += " \u{00B7} next look at \(n) more tier\(n == 1 ? "" : "s")"
        }
        tierLabel.text = text

        rows.removeFromParent()
        rows = SKNode()
        buyButtons = []
        for (i, track) in UpgradeTrack.allCases.enumerated() {
            let row = makeRow(track: track, state: state)
            row.position = CGPoint(x: 0, y: rowsTop - Self.rowHeight / 2 - CGFloat(i) * (Self.rowHeight + Self.rowGap))
            rows.addChild(row)
            let pos = CGPoint(x: 126, y: row.position.y)
            let size = CGSize(width: 96, height: 36)
            let block = state.purchaseBlock(for: track)
            let name = "buy:\(track.rawValue)"
            switch block {
            case .maxed?:
                let b = Button(title: "MAX", name: name, size: size, style: .outlined)
                b.isEnabled = false
                b.position = pos
                rows.addChild(b)
            case .lockedUntil(let level)?:
                let b = Button(title: "LVL \(level)", name: name, size: size, style: .outlined)
                b.isEnabled = false
                b.position = pos
                rows.addChild(b)
            default:
                let cost = state.upgrades.nextCost(for: track) ?? 0
                let b = Button(title: "\u{25C6} " + (Self.formatter.string(from: NSNumber(value: cost)) ?? "\(cost)"), name: name, size: size, style: .filled)
                b.isEnabled = block == nil
                b.position = pos
                rows.addChild(b)
                buyButtons.append((track, b))
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
        let next: String
        if tier >= PermanentUpgrades.maxTier {
            next = "Maxed"
        } else if case .lockedUntil(let level)? = state.purchaseBlock(for: track) {
            next = "Unlocks after level \(level)"
        } else {
            next = state.upgrades.effectDescription(for: track, atTier: tier + 1)
        }
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
        let now = CACurrentMediaTime()
        guard now - lastPurchaseTime >= Self.buyDebounce else { return }
        if flow.state.canAfford(hit.track), flow.purchase(hit.track) {
            lastPurchaseTime = now
            let newTier = flow.state.upgrades.visualTier
            refresh()
            if newTier != shownTier {
                shownTier = newTier
                rebuildHive()
                hive?.run(.sequence([
                    .scale(to: hiveScale * 1.12, duration: 0.12),
                    .scale(to: hiveScale, duration: 0.13),
                ]))
            }
        } else if flow.state.purchaseBlock(for: hit.track) == .cannotAfford {
            // Only an unaffordable tier shakes the balance; a locked (or maxed) tier ignores the tap.
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
