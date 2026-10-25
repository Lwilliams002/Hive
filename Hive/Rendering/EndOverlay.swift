import SpriteKit
import HiveCore

/// Results card shown when a run ends: outcome, wave reached, coins earned, and next actions. With `onDoubleCoins`
/// (M4 R19, R25: a rewarded ad is ready and the run pays out) a DOUBLE COINS button heads the stack; it lives outside
/// the single-shot `actions`, so CONTINUE / RETRY / HOME stay live after the reward.
final class EndOverlay: SKNode {
    private var actions: [(Button, () -> Void)] = []
    private var isDone = false
    private var onDoubleCoins: (() -> Void)?
    private var doubleButton: Button?
    private let coinsLabel = SKLabelNode(fontNamed: Typography.font)

    init(result: RunResult, previousBest: Int = 0, viewSize: CGSize, onContinue: (() -> Void)?,
         onRetry: @escaping () -> Void, onHome: @escaping () -> Void, onDoubleCoins: (() -> Void)? = nil) {
        self.onDoubleCoins = onDoubleCoins
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let isEndless = result.mode == .endless
        let cleared = result.cleared
        let newBest = isEndless && result.wavesCleared > previousBest
        let title = SKLabelNode(fontNamed: Typography.font)
        if isEndless {
            let n = result.wavesCleared
            title.text = newBest ? "NEW BEST \u{00B7} \(n) \(n == 1 ? "WAVE" : "WAVES")" : "SWARM OVERRAN THE HIVE"
        } else {
            title.text = cleared ? "HIVE SURVIVED" : "HIVE FELL"
        }
        title.fontSize = Typography.title
        title.fontColor = (cleared || newBest) ? Palette.gold : Palette.white
        if !cleared && !newBest { title.alpha = 0.9 }
        // Long endless titles shrink to fit the card width.
        let maxWidth = viewSize.width - 48
        if title.frame.width > maxWidth { title.fontSize = Typography.title * maxWidth / title.frame.width }
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 130)
        addChild(title)

        let reached = cleared ? result.totalWaves : result.wavesCleared + 1
        let sub = SKLabelNode(fontNamed: Typography.font)
        if isEndless {
            let n = result.wavesCleared
            sub.text = n == 0 ? "No waves cleared" : "Survived \(n) \(n == 1 ? "wave" : "waves")"
        } else {
            sub.text = "Reached wave \(reached)"
        }
        sub.fontSize = 14
        sub.fontColor = Palette.white
        sub.alpha = 0.7
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 92)
        addChild(sub)

        // Stored so `setDoubled` can rewrite it to the doubled total.
        coinsLabel.text = "+\(result.coinsEarned) coins"
        coinsLabel.fontSize = 22
        coinsLabel.fontColor = Palette.gold
        coinsLabel.verticalAlignmentMode = .center
        coinsLabel.position = CGPoint(x: 0, y: 46)
        addChild(coinsLabel)

        // Pitch 66: without DOUBLE COINS the rows sit at -20 / -86 / -152 as before; with it DOUBLE COINS takes -20 and
        // CONTINUE / RETRY / HOME move to -86 / -152 / -218 (bottom edge -244, inside 667 pt; the nectar bar at -285.5
        // is behind the 0.72 dim).
        let hasDouble = onDoubleCoins != nil
        var y: CGFloat = -20
        if hasDouble {
            let b = Button(title: "DOUBLE COINS", name: "double", style: .filled)
            b.position = CGPoint(x: 0, y: y)
            addChild(b)
            doubleButton = b   // never in `actions`: hit-tested first in `handleTouch`
            y -= 66
        }
        if cleared, !isEndless, let onContinue = onContinue {
            // Only one filled button shows: CONTINUE yields the emphasis to DOUBLE COINS when both are up.
            add(Button(title: "CONTINUE", name: "continue", style: hasDouble ? .outlined : .filled), at: y,
                action: onContinue)
            y -= 66
        }
        add(Button(title: (cleared && !isEndless) ? "PLAY AGAIN" : "RETRY", name: "retry", style: .outlined), at: y, action: onRetry)
        y -= 66
        add(Button(title: "HOME", name: "home", style: .outlined), at: y, action: onHome)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func add(_ button: Button, at y: CGFloat, action: @escaping () -> Void) {
        button.position = CGPoint(x: 0, y: y)
        addChild(button)
        actions.append((button, action))
    }

    /// `point` is in the overlay's coordinate space. DOUBLE COINS is hit-tested before `actions` and fires whenever it
    /// is enabled; the actions fire at most once. The overlay stays in place: HOME/CONTINUE leave the scene under a
    /// fade that covers it, and RETRY's restart removes it.
    func handleTouch(at point: CGPoint) {
        guard !isDone else { return }
        // A disabled or hidden button never `contains` a point, so a pending or spent DOUBLE COINS falls through.
        if let b = doubleButton, b.contains(point) {
            onDoubleCoins?()
            return
        }
        guard let hit = actions.first(where: { $0.0.contains(point) }) else { return }
        isDone = true
        actions.removeAll()
        hit.1()
    }

    /// The rewarded ad is up: DOUBLE COINS dims until `setDoubled` or `setDoubleAvailable` resolves it.
    func setDoublePending() {
        doubleButton?.isEnabled = false
    }

    /// The ad was cancelled or failed: DOUBLE COINS comes back only while another ad is ready, else it is hidden
    /// (never shown broken, R25).
    func setDoubleAvailable(_ ready: Bool) {
        doubleButton?.isEnabled = ready
        doubleButton?.isHidden = !ready
    }

    /// The bonus was banked: the coins line shows the doubled total and the button stays visible, disabled, as
    /// DOUBLED (R25); no further tap can fire.
    func setDoubled(total: Int) {
        coinsLabel.text = "+\(total) coins"
        doubleButton?.setTitle("DOUBLED")
        doubleButton?.isEnabled = false
        onDoubleCoins = nil
    }
}
