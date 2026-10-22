import SpriteKit

final class PauseOverlay: SKNode {
    private var onResume: (() -> Void)?

    init(viewSize: CGSize, onResume: @escaping () -> Void) {
        self.onResume = onResume
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = "PAUSED"
        title.fontSize = 30
        title.fontColor = Palette.white
        title.alpha = 0.9
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 50)
        addChild(title)

        let button = SKShapeNode(rectOf: CGSize(width: 220, height: 52), cornerRadius: 14)
        button.fillColor = Palette.amber
        button.strokeColor = .clear
        button.position = CGPoint(x: 0, y: -30)
        button.name = "resume"
        addChild(button)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "RESUME"
        label.fontSize = 16
        label.fontColor = Palette.background
        label.verticalAlignmentMode = .center
        button.addChild(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// `point` is in the overlay's coordinate space.
    func handleTouch(at point: CGPoint) {
        guard let onResume = onResume else { return }
        for hit in nodes(at: point) {
            var node: SKNode? = hit
            while let n = node {
                if n.name == "resume" {
                    self.onResume = nil
                    removeFromParent()
                    onResume()
                    return
                }
                node = n.parent
            }
        }
    }
}
