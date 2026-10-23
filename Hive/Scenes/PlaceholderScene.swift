import SpriteKit

/// Temporary screen with a title and BACK button; replaced by the real upgrades and level-select scenes.
final class PlaceholderScene: SKScene {
    private unowned let flow: AppFlow
    private let titleText: String
    private let back = Button(title: "BACK", name: "back", style: .outlined)
    private var didLeave = false

    init(title: String, flow: AppFlow, size: CGSize) {
        self.titleText = title
        self.flow = flow
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
        removeAllChildren()
        didLeave = false
        let label = SKLabelNode(fontNamed: Typography.font)
        label.text = titleText
        label.fontSize = Typography.title
        label.fontColor = Palette.gold
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: size.height * 0.1)
        addChild(label)
        back.position = CGPoint(x: 0, y: -size.height * 0.1)
        addChild(back)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !didLeave, let touch = touches.first, back.contains(touch.location(in: self)) else { return }
        didLeave = true
        flow.showHome()
    }
}
