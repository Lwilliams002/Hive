import SpriteKit

/// Pause menu: RESUME (filled), then RETRY and HOME (outlined). Fires at most one callback.
final class PauseOverlay: SKNode {
    private var onResume: (() -> Void)?
    private var onRetry: (() -> Void)?
    private var onHome: (() -> Void)?
    private let resume = Button(title: "RESUME", name: "resume", style: .filled)
    private let retry = Button(title: "RETRY", name: "retry", style: .outlined)
    private let home = Button(title: "HOME", name: "home", style: .outlined)
    private var isDone = false

    init(viewSize: CGSize, onResume: @escaping () -> Void,
         onRetry: @escaping () -> Void, onHome: @escaping () -> Void) {
        self.onResume = onResume
        self.onRetry = onRetry
        self.onHome = onHome
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

        let pitch: CGFloat = 52 + 12
        resume.position = CGPoint(x: 0, y: -30)
        retry.position = CGPoint(x: 0, y: -30 - pitch)
        home.position = CGPoint(x: 0, y: -30 - 2 * pitch)
        for b in [resume, retry, home] { addChild(b) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// `point` is in the overlay's coordinate space. RESUME removes the overlay; RETRY's restart removes it,
    /// and HOME leaves it in place under the scene fade.
    func handleTouch(at point: CGPoint) {
        guard !isDone else { return }
        let action: (() -> Void)?
        if resume.contains(point) {
            action = onResume
            removeFromParent()
        } else if retry.contains(point) {
            action = onRetry
        } else if home.contains(point) {
            action = onHome
        } else {
            return
        }
        isDone = true
        onResume = nil
        onRetry = nil
        onHome = nil
        action?()
    }
}
