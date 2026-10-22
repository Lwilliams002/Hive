import SpriteKit

final class HiveNode: SKNode {
    init(tier: Int) {
        super.init()

        let glow = SKShapeNode(circleOfRadius: 48)
        glow.fillColor = Palette.amber
        glow.strokeColor = .clear
        glow.alpha = 0.12
        glow.glowWidth = 18
        glow.zPosition = -1
        addChild(glow)
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.06, duration: 1.4),
            .scale(to: 1.0, duration: 1.4)
        ])))

        addChild(cell(radius: 16, color: Palette.gold, at: .zero))
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3
            addChild(cell(radius: 14, color: Palette.amber,
                          at: CGPoint(x: 28 * cos(a), y: 28 * sin(a))))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func cell(radius: CGFloat, color: UIColor, at p: CGPoint) -> SKShapeNode {
        let n = SKShapeNode(path: Shapes.hexPath(circumradius: radius))
        n.fillColor = color
        n.strokeColor = Palette.burntOrange
        n.lineWidth = 1.5
        n.glowWidth = 6
        n.position = p
        return n
    }
}
