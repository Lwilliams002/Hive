import SpriteKit

/// Honey Field: a faint amber disc around the hive marking where mobs are slowed.
final class SlowFieldNode: SKNode {
    let radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius
        super.init()
        let disc = SKShapeNode(circleOfRadius: radius)
        disc.fillColor = Palette.amber.withAlphaComponent(0.03)
        disc.strokeColor = Palette.amber.withAlphaComponent(0.2)
        disc.lineWidth = 1
        addChild(disc)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
