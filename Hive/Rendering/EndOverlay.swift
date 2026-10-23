import SpriteKit
import HiveCore

/// Results card shown when a run ends: outcome, wave reached, coins earned, and next actions.
final class EndOverlay: SKNode {
    private var actions: [(Button, () -> Void)] = []
    private var isDone = false

    init(result: RunResult, viewSize: CGSize, onContinue: (() -> Void)?,
         onRetry: @escaping () -> Void, onHome: @escaping () -> Void) {
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let cleared = result.cleared
        let title = SKLabelNode(fontNamed: Typography.font)
        title.text = cleared ? "HIVE SURVIVED" : "HIVE FELL"
        title.fontSize = Typography.title
        title.fontColor = cleared ? Palette.gold : Palette.white
        if !cleared { title.alpha = 0.9 }
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 130)
        addChild(title)

        let reached = cleared ? result.totalWaves : result.wavesCleared + 1
        let sub = SKLabelNode(fontNamed: Typography.font)
        sub.text = "Reached wave \(reached)"
        sub.fontSize = 14
        sub.fontColor = Palette.white
        sub.alpha = 0.7
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 92)
        addChild(sub)

        let coins = SKLabelNode(fontNamed: Typography.font)
        coins.text = "+\(result.coinsEarned) coins"
        coins.fontSize = 22
        coins.fontColor = Palette.gold
        coins.verticalAlignmentMode = .center
        coins.position = CGPoint(x: 0, y: 46)
        addChild(coins)

        var y: CGFloat = -20
        if cleared, let onContinue = onContinue {
            add(Button(title: "CONTINUE", name: "continue", style: .filled), at: y, action: onContinue)
            y -= 66
        }
        add(Button(title: cleared ? "PLAY AGAIN" : "RETRY", name: "retry", style: .outlined), at: y, action: onRetry)
        y -= 66
        add(Button(title: "HOME", name: "home", style: .outlined), at: y, action: onHome)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func add(_ button: Button, at y: CGFloat, action: @escaping () -> Void) {
        button.position = CGPoint(x: 0, y: y)
        addChild(button)
        actions.append((button, action))
    }

    /// `point` is in the overlay's coordinate space. Fires at most one action. The overlay stays in place:
    /// HOME/CONTINUE leave the scene under a fade that covers it, and RETRY's restart removes it.
    func handleTouch(at point: CGPoint) {
        guard !isDone, let hit = actions.first(where: { $0.0.contains(point) }) else { return }
        isDone = true
        actions.removeAll()
        hit.1()
    }
}
