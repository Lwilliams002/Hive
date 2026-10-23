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
            shape = SKShapeNode(path: Shapes.hexPath(circumradius: 14))
            baseColor = Palette.violet
        case .bear:
            shape = SKShapeNode(rectOf: CGSize(width: 60, height: 50), cornerRadius: 14)
            baseColor = Palette.sicklyGreen
        case .beetle:
            shape = SKShapeNode(path: Shapes.hexPath(circumradius: 13))
            baseColor = Palette.beetle
        case .hornetQueen:
            shape = SKShapeNode(path: Shapes.hexPath(circumradius: 26))
            baseColor = Palette.violet
        case .swarmMother:
            shape = SKShapeNode(path: Shapes.hexPath(circumradius: 22))
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
        if type == .beetle {
            // Rounded corners so the armoured shell reads softer than the hornet's hex.
            shape.lineJoin = .round
            shape.lineWidth = 3
        }
        addChild(shape)

        switch type {
        case .beetle:
            addChild(Self.frontArc())
        case .hornetQueen:
            let inner = SKShapeNode(path: Shapes.hexPath(circumradius: 12))
            inner.fillColor = Palette.gold.withAlphaComponent(0.5)
            inner.strokeColor = .clear
            shape.addChild(inner)
            let ring = SKShapeNode(circleOfRadius: 30)
            ring.fillColor = .clear
            ring.strokeColor = Palette.violet.withAlphaComponent(0.5)
            ring.lineWidth = 1
            addChild(ring)
        case .swarmMother:
            let orbit = SKNode()
            for i in 0..<3 {
                let a = CGFloat(i) * 2 * .pi / 3
                let dot = SKShapeNode(circleOfRadius: 3)
                dot.fillColor = Palette.slate
                dot.strokeColor = .clear
                dot.position = CGPoint(x: 28 * cos(a), y: 28 * sin(a))
                orbit.addChild(dot)
            }
            orbit.run(.repeatForever(.rotate(byAngle: 2 * .pi, duration: 3)))
            addChild(orbit)
        case .wasp, .hornet, .bear:
            break
        }

        if type.stats.isBoss {
            run(.repeatForever(.sequence([.fadeAlpha(to: 0.85, duration: 1.0),
                                          .fadeAlpha(to: 1.0, duration: 1.0)])))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// The beetle's shielded front: a 110° arc toward local +x (the node faces the hive via `zRotation`).
    private static func frontArc() -> SKShapeNode {
        let half = CGFloat(110) / 2 * .pi / 180
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 15, startAngle: -half, endAngle: half, clockwise: false)
        let arc = SKShapeNode(path: path)
        arc.fillColor = .clear
        arc.strokeColor = Palette.white.withAlphaComponent(0.35)
        arc.lineWidth = 3
        arc.lineCap = .round
        return arc
    }

    func setHitFlash(_ on: Bool) {
        shape.fillColor = on ? Palette.white : baseColor
    }
}
