import SpriteKit

/// Revive prompt shown when the hive falls while a rewarded ad is ready (M4 R3, R25): REVIVE (filled) watches the ad,
/// GIVE UP (outlined) lets the hive fall. Fires at most one callback and never removes itself — the scene does, once
/// the ad has been dismissed or at once on GIVE UP.
final class ReviveOverlay: SKNode {
    private var onRevive: (() -> Void)?
    private var onGiveUp: (() -> Void)?
    private let revive = Button(title: "REVIVE", name: "revive", style: .filled)
    private let giveUp = Button(title: "GIVE UP", name: "giveup", style: .outlined)
    private var isDone = false

    init(viewSize: CGSize, onRevive: @escaping () -> Void, onGiveUp: @escaping () -> Void) {
        self.onRevive = onRevive
        self.onGiveUp = onGiveUp
        super.init()
        zPosition = 200

        let dim = SKSpriteNode(color: .black, size: viewSize)
        dim.alpha = 0.72
        addChild(dim)

        let title = SKLabelNode(fontNamed: Typography.font)
        title.text = "THE HIVE IS FALLING"
        title.fontSize = Typography.title
        title.fontColor = Palette.white
        title.alpha = 0.9
        // Shrinks to fit the card width on narrow screens (pattern of `EndOverlay`); at 375 pt it fits as is.
        let maxWidth = viewSize.width - 48
        if title.frame.width > maxWidth { title.fontSize = Typography.title * maxWidth / title.frame.width }
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 50)
        addChild(title)

        let sub = SKLabelNode(fontNamed: Typography.font)
        sub.text = "Watch an ad to rebuild at 50% HP"
        sub.fontSize = 14
        sub.fontColor = Palette.gold
        sub.alpha = 0.8
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 14)
        addChild(sub)

        revive.position = CGPoint(x: 0, y: -30)
        giveUp.position = CGPoint(x: 0, y: -94)
        for b in [revive, giveUp] { addChild(b) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// `point` is in the overlay's coordinate space. Fires at most one callback and leaves the overlay in place:
    /// REVIVE keeps it up (dimmed via `setWaiting`) under the ad, and the scene removes it on the ad's dismiss or on
    /// GIVE UP.
    func handleTouch(at point: CGPoint) {
        guard !isDone else { return }
        let action: (() -> Void)?
        if revive.contains(point) {
            action = onRevive
        } else if giveUp.contains(point) {
            action = onGiveUp
        } else {
            return
        }
        isDone = true
        onRevive = nil
        onGiveUp = nil
        action?()
    }

    /// Dims both buttons while the rewarded ad is up.
    func setWaiting() {
        revive.isEnabled = false
        giveUp.isEnabled = false
    }
}
