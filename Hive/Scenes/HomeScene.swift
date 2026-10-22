import SpriteKit

/// Placeholder home screen: coin balance and a PLAY button. Replaced in a later task.
final class HomeScene: SKScene {
    private unowned let flow: AppFlow
    private let play = Button(title: "PLAY", name: "play", style: .filled)

    init(flow: AppFlow, size: CGSize) {
        self.flow = flow
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
        removeAllChildren()

        let top = size.height / 2
        let title = SKLabelNode(fontNamed: Typography.font)
        title.text = "HOME"
        title.fontSize = Typography.small
        title.fontColor = Palette.gold
        title.alpha = 0.5
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: top - 80)
        addChild(title)

        let balance = SKLabelNode(fontNamed: Typography.font)
        balance.text = "\u{25C6} \(flow.state.coins)"
        balance.fontSize = 16
        balance.fontColor = Palette.gold
        balance.verticalAlignmentMode = .center
        balance.position = CGPoint(x: 0, y: top - 108)
        addChild(balance)

        play.isEnabled = !flow.levels.availableLevelIDs().isEmpty
        play.position = .zero
        addChild(play)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, play.contains(touch.location(in: self)) else { return }
        let ids = flow.levels.availableLevelIDs()
        guard let maxID = ids.max() else { return }
        flow.startLevel(id: min(flow.state.currentLevel, maxID))
    }
}
