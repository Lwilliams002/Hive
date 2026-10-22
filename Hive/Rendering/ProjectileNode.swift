import SpriteKit

final class ProjectileNode: SKShapeNode {
    override init() {
        super.init()
        path = CGPath(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8), transform: nil)
        fillColor = Palette.white
        strokeColor = .clear
        glowWidth = 4
        alpha = 0.95
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
