import SpriteKit
import HiveCore

/// Card pick shown between waves: the regular cards plus (M4 R11, R25) a fourth, premium row when World rolled a
/// locked card and a rewarded ad is ready. A regular row removes the overlay and reports the pick at once; the premium
/// row fires `onPremium` once and dims, and the overlay stays up under the ad — the scene calls `finishPremiumPick()`
/// when the reward was granted and leaves the same four rows (premium dimmed) when it was cancelled.
final class CardPickOverlay: SKNode {
    private var onPick: ((UpgradeCard) -> Void)?
    private let onPremium: ((UpgradeCard) -> Void)?
    private let cards: [UpgradeCard]
    private let premium: UpgradeCard?
    private var premiumEnabled = true
    private var premiumRow: SKShapeNode?

    private static let cardW: CGFloat = 300, cardH: CGFloat = 84, gap: CGFloat = 14

    init(cards: [UpgradeCard], premium: UpgradeCard?, viewSize: CGSize, onPick: @escaping (UpgradeCard) -> Void,
         onPremium: ((UpgradeCard) -> Void)?) {
        self.cards = cards
        self.premium = premium
        self.onPick = onPick
        self.onPremium = onPremium
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        // Rows pitch 98 (84 + 14). Three rows: totalH 280, title centre 180. Four rows: totalH 378, title centre 229,
        // cards span ±189 — fits 375×667 with ~97 pt above the title and ~144 pt below the last card.
        let cardH = Self.cardH, gap = Self.gap
        let rowCount = CGFloat(cards.count + (premium == nil ? 0 : 1))
        let totalH = rowCount * cardH + (rowCount - 1) * gap

        let title = SKLabelNode(fontNamed: Typography.font)
        title.text = "C H O O S E   A N   U P G R A D E"
        title.fontSize = 14
        title.fontColor = Palette.gold
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: totalH / 2 + 40)
        addChild(title)

        for (i, card) in cards.enumerated() {
            let row = Self.makeRow(card, isPremium: false)
            row.position = CGPoint(x: 0, y: totalH / 2 - cardH / 2 - CGFloat(i) * (cardH + gap))
            addChild(row)
        }
        // The premium row is always the last one; its `premium:` name cannot collide with a `card:` row because the
        // locked pool is disjoint from the pick pool.
        if let premium = premium {
            let row = Self.makeRow(premium, isPremium: true)
            row.position = CGPoint(x: 0, y: totalH / 2 - cardH / 2 - CGFloat(cards.count) * (cardH + gap))
            addChild(row)
            premiumRow = row
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// One 300×84 row named `card:<id>` (or `premium:<id>`). Common amber, rare gold, epic white; the premium row
    /// always reads as an epic, on a burnt-orange fill, with its rarity tag replaced by WATCH TO TAKE and the unlock
    /// level in the bottom-right corner.
    private static func makeRow(_ card: UpgradeCard, isPremium: Bool) -> SKShapeNode {
        let rarity: CardRarity = isPremium ? .epic : card.rarity
        let rare = rarity != .common
        let shape = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 14)
        shape.fillColor = isPremium
            ? Palette.burntOrange.withAlphaComponent(0.25)
            : UIColor(red: 0x15 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)
        let accent: UIColor
        switch rarity {
        case .common: accent = Palette.amber
        case .rare: accent = Palette.gold
        case .epic: accent = Palette.white
        }
        shape.strokeColor = accent.withAlphaComponent(rare ? 0.9 : 0.6)
        shape.lineWidth = rare ? 2 : 1
        shape.name = (isPremium ? "premium:" : "card:") + card.id

        let name = SKLabelNode(fontNamed: Typography.font)
        name.text = card.name
        name.fontSize = 18
        name.fontColor = Palette.white
        name.horizontalAlignmentMode = .left
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: -cardW / 2 + 18, y: 12)
        shape.addChild(name)

        let desc = SKLabelNode(fontNamed: Typography.font)
        desc.text = card.description
        desc.fontSize = 13
        desc.fontColor = Palette.gold
        desc.alpha = 0.8
        desc.horizontalAlignmentMode = .left
        desc.verticalAlignmentMode = .center
        desc.position = CGPoint(x: -cardW / 2 + 18, y: -14)
        // Long descriptions (e.g. Honey Field) shrink to stay inside the card.
        let maxDescW = cardW - 36
        if desc.frame.width > maxDescW {
            desc.fontSize *= maxDescW / desc.frame.width
        }
        shape.addChild(desc)

        let tag = SKLabelNode(fontNamed: Typography.font)
        tag.text = isPremium ? "WATCH TO TAKE" : card.rarity.rawValue.uppercased()
        tag.fontSize = 10
        tag.fontColor = isPremium ? Palette.gold : accent
        tag.alpha = 0.8
        tag.horizontalAlignmentMode = .right
        tag.verticalAlignmentMode = .center
        tag.position = CGPoint(x: cardW / 2 - 14, y: cardH / 2 - 14)
        shape.addChild(tag)

        if isPremium {
            let lock = SKLabelNode(fontNamed: Typography.font)
            lock.text = "LOCKED \u{00B7} UNLOCKS AFTER LEVEL \(card.unlockLevel)"
            lock.fontSize = 10
            lock.fontColor = Palette.white
            lock.alpha = 0.5
            lock.horizontalAlignmentMode = .right
            lock.verticalAlignmentMode = .center
            lock.position = CGPoint(x: cardW / 2 - 14, y: -cardH / 2 + 12)
            shape.addChild(lock)
        }
        return shape
    }

    /// `point` is in the overlay's coordinate space. A `card:` row removes the overlay and reports the pick; the
    /// `premium:` row, only while enabled, dims itself and fires `onPremium` without removing anything — the scene
    /// finishes the pick after the ad, or leaves the rows as they are when it was cancelled (R11).
    func handleTouch(at point: CGPoint) {
        guard let onPick = onPick else { return }
        for hit in nodes(at: point) {
            var node: SKNode? = hit
            while let n = node {
                if let name = n.name, name.hasPrefix("card:") {
                    let id = String(name.dropFirst("card:".count))
                    if let card = cards.first(where: { $0.id == id }) {
                        self.onPick = nil
                        removeFromParent()
                        onPick(card)
                        return
                    }
                } else if let name = n.name, name.hasPrefix("premium:"), let card = premium {
                    guard premiumEnabled else { return }
                    setPremiumEnabled(false)
                    onPremium?(card)
                    return
                }
                node = n.parent
            }
        }
    }

    /// Dims the premium row while the rewarded ad is up; it stays dimmed when the ad is cancelled or fails (R11).
    func setPremiumEnabled(_ on: Bool) {
        premiumEnabled = on
        premiumRow?.alpha = on ? 1 : 0.35
    }

    /// The reward was granted: the scene consumes the pick with the premium card, so the overlay goes away exactly as
    /// after a regular pick.
    func finishPremiumPick() {
        onPick = nil
        removeFromParent()
    }
}
