import SpriteKit

final class PauseOverlay: SKNode {
    private var onResume: (() -> Void)?
    private let resume = Button(title: "RESUME", name: "resume", style: .filled)

    init(viewSize: CGSize, onResume: @escaping () -> Void) {
        self.onResume = onResume
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let title = SKLabelNode(fontNamed: Typography.font)
        title.text = "PAUSED"
        title.fontSize = Typography.title
        title.fontColor = Palette.white
        title.alpha = 0.9
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 50)
        addChild(title)

        resume.position = CGPoint(x: 0, y: -30)
        addChild(resume)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// `point` is in the overlay's coordinate space.
    func handleTouch(at point: CGPoint) {
        guard let onResume = onResume, resume.contains(point) else { return }
        self.onResume = nil
        removeFromParent()
        onResume()
    }
}
