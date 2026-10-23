import SpriteKit

/// Honey Field: a faint amber disc around the hive marking where mobs are slowed.
final class SlowFieldNode: SKNode {
    let radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius
        super.init()
        let spinner = SKNode()
        let disc = SKShapeNode(circleOfRadius: radius)
        disc.fillColor = Palette.amber.withAlphaComponent(0.05)
        disc.strokeColor = Palette.amber.withAlphaComponent(0.2)
        disc.lineWidth = 1
        spinner.addChild(disc)
        spinner.run(.repeatForever(.rotate(byAngle: 2 * .pi, duration: 20)))
        addChild(spinner)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
