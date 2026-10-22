import SpriteKit

/// Rounded-rect text button. Hit-test with `contains(_:)` using a point in the button's parent space.
final class Button: SKNode {
    enum Style { case filled, outlined }

    private let size: CGSize
    private let shape: SKShapeNode
    private let label = SKLabelNode(fontNamed: Typography.font)

    var isEnabled = true {
        didSet { alpha = isEnabled ? 1 : 0.35 }
    }

    init(title: String, name: String, size: CGSize = CGSize(width: 220, height: 52), style: Style) {
        self.size = size
        shape = SKShapeNode(path: Shapes.roundedRect(size, corner: 14))
        super.init()
        self.name = name

        switch style {
        case .filled:
            shape.fillColor = Palette.amber
            shape.strokeColor = .clear
            label.fontColor = Palette.background
        case .outlined:
            shape.fillColor = .clear
            shape.strokeColor = Palette.amber.withAlphaComponent(0.8)
            shape.lineWidth = 1.5
            label.fontColor = Palette.gold
        }
        addChild(shape)

        label.text = title
        label.fontSize = 16
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// `point` is in the parent's coordinate space. Disabled or hidden buttons never contain a point.
    override func contains(_ point: CGPoint) -> Bool {
        guard isEnabled, !isHidden, parent != nil else { return false }
        let local = CGPoint(x: point.x - position.x, y: point.y - position.y)
        return abs(local.x) <= size.width / 2 && abs(local.y) <= size.height / 2
    }
}
