import SpriteKit
import HiveCore

final class MobNode: SKNode {
    private let shape: SKShapeNode
    private let baseColor: UIColor

    init(type: MobType) {
        switch type {
        case .wasp:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 10, y: 0))
            p.addLine(to: CGPoint(x: 0, y: 6))
            p.addLine(to: CGPoint(x: -10, y: 0))
            p.addLine(to: CGPoint(x: 0, y: -6))
            p.closeSubpath()
            shape = SKShapeNode(path: p)
            baseColor = Palette.slate
        case .hornet:
            let p = CGMutablePath()
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                let pt = CGPoint(x: 14 * cos(a), y: 14 * sin(a))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            shape = SKShapeNode(path: p)
            baseColor = Palette.violet
        case .bear:
            shape = SKShapeNode(rectOf: CGSize(width: 60, height: 50), cornerRadius: 14)
            baseColor = Palette.sicklyGreen
        }
        super.init()
        shape.fillColor = baseColor
        shape.lineWidth = 1
        if type == .bear {
            shape.strokeColor = Palette.white.withAlphaComponent(0.25)
        } else {
            shape.strokeColor = baseColor
        }
        addChild(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func setHitFlash(_ on: Bool) {
        shape.fillColor = on ? Palette.white : baseColor
    }
}
