import SpriteKit

final class EndOverlay: SKNode {
    private var onRetry: (() -> Void)?

    init(cleared: Bool, wave: Int, viewSize: CGSize, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = cleared ? "HIVE SURVIVED" : "HIVE FELL"
        title.fontSize = 30
        title.fontColor = cleared ? Palette.gold : Palette.white
        if !cleared { title.alpha = 0.9 }
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 70)
        addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = "Reached wave \(wave)"
        sub.fontSize = 14
        sub.fontColor = Palette.white
        sub.alpha = 0.7
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 30)
        addChild(sub)

        let button = SKShapeNode(rectOf: CGSize(width: 220, height: 52), cornerRadius: 14)
        button.fillColor = Palette.amber
        button.strokeColor = .clear
        button.position = CGPoint(x: 0, y: -40)
        button.name = "retry"
        addChild(button)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "RETRY"
        label.fontSize = 16
        label.fontColor = Palette.background
        label.verticalAlignmentMode = .center
        button.addChild(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func handleTouch(at point: CGPoint) {
        guard let onRetry = onRetry else { return }
        for hit in nodes(at: point) {
            var node: SKNode? = hit
            while let n = node {
                if n.name == "retry" {
                    self.onRetry = nil
                    removeFromParent()
                    onRetry()
                    return
                }
                node = n.parent
            }
        }
    }
}
