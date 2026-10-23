import SpriteKit

/// A guard bee orbiting the hive: small gold body with a pale core.
final class GuardBeeNode: SKShapeNode {
    override init() {
        super.init()
        path = CGPath(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10), transform: nil)
        fillColor = Palette.gold
        strokeColor = .clear
        let core = SKShapeNode(circleOfRadius: 2)
        core.fillColor = Palette.white.withAlphaComponent(0.6)
        core.strokeColor = .clear
        addChild(core)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
