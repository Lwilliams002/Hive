import SpriteKit
import HiveCore

/// Names an incoming boss and its tell; same placement as the starting-cards banner.
final class BossBanner: SKNode {
    init(title: String, subtitle: String, viewSize: CGSize) {
        super.init()
        position = CGPoint(x: 0, y: viewSize.height / 4)
        zPosition = 90

        let name = SKLabelNode(fontNamed: Typography.font)
        name.text = title
        name.fontSize = 22
        name.fontColor = Palette.white
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: 10)
        addChild(name)

        let tell = SKLabelNode(fontNamed: Typography.font)
        tell.text = subtitle
        tell.fontSize = 12
        tell.fontColor = Palette.gold
        tell.alpha = 0.8
        tell.verticalAlignmentMode = .center
        tell.position = CGPoint(x: 0, y: -12)
        addChild(tell)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// Title and tell for a boss type; nil for non-boss mobs.
    static func text(for type: MobType) -> (title: String, subtitle: String)? {
        switch type {
        case .bear: return ("BEAR", "tanks damage")
        case .hornetQueen: return ("HORNET QUEEN", "spawns escorts")
        case .swarmMother: return ("SWARM MOTHER", "calls the swarm")
        case .wasp, .hornet, .beetle: return nil
        }
    }
}
