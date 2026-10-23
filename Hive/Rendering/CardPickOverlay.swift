import SpriteKit
import HiveCore

final class CardPickOverlay: SKNode {
    private var onPick: ((UpgradeCard) -> Void)?
    private let cards: [UpgradeCard]

    init(cards: [UpgradeCard], viewSize: CGSize, onPick: @escaping (UpgradeCard) -> Void) {
        self.cards = cards
        self.onPick = onPick
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let cardW: CGFloat = 300, cardH: CGFloat = 84, gap: CGFloat = 14
        let count = CGFloat(cards.count)
        let totalH = count * cardH + (count - 1) * gap

        let title = SKLabelNode(fontNamed: Typography.font)
        title.text = "C H O O S E   A N   U P G R A D E"
        title.fontSize = 14
        title.fontColor = Palette.gold
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: totalH / 2 + 40)
        addChild(title)

        for (i, card) in cards.enumerated() {
            let y = totalH / 2 - cardH / 2 - CGFloat(i) * (cardH + gap)
            let rare = card.rarity != .common
            let shape = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 14)
            shape.fillColor = UIColor(red: 0x15 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)
            // Common amber, rare gold, epic white.
            let accent: UIColor
            switch card.rarity {
            case .common: accent = Palette.amber
            case .rare: accent = Palette.gold
            case .epic: accent = Palette.white
            }
            shape.strokeColor = accent.withAlphaComponent(card.rarity == .common ? 0.6 : 0.9)
            shape.lineWidth = rare ? 2 : 1
            shape.position = CGPoint(x: 0, y: y)
            shape.name = "card:\(card.id)"
            addChild(shape)

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
            tag.text = card.rarity.rawValue.uppercased()
            tag.fontSize = 10
            tag.fontColor = accent
            tag.alpha = 0.8
            tag.horizontalAlignmentMode = .right
            tag.verticalAlignmentMode = .center
            tag.position = CGPoint(x: cardW / 2 - 14, y: cardH / 2 - 14)
            shape.addChild(tag)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// `point` is in the overlay's coordinate space.
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
                }
                node = n.parent
            }
        }
    }
}
