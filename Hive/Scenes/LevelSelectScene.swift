import SpriteKit
import HiveCore

/// Level list: one row per available level, CLEARED / CURRENT / LOCKED, scrollable when taller than the view.
final class LevelSelectScene: SKScene {
    private unowned let flow: AppFlow
    private let back = Button(title: "BACK", name: "back", size: CGSize(width: 100, height: 40), style: .outlined)
    private let container = SKNode()
    private var rowIDs: [(id: Int, node: SKNode, playable: Bool)] = []
    private var didStart = false
    private var didLeave = false
    private var touchStart: CGPoint?
    private var lastY: CGFloat = 0
    private var totalMove: CGFloat = 0
    private var maxScroll: CGFloat = 0

    private static let rowSize = CGSize(width: 300, height: 56)
    private static let gap: CGFloat = 12

    init(flow: AppFlow, size: CGSize) {
        self.flow = flow
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
        removeAllChildren()
        container.removeAllChildren()
        container.position = .zero
        rowIDs = []
        didStart = false
        didLeave = false
        let w = size.width
        let h = size.height

        back.position = CGPoint(x: -w / 2 + 70, y: h / 2 - 60)
        addChild(back)

        let title = SKLabelNode(fontNamed: Typography.font)
        title.attributedText = NSAttributedString(string: "LEVELS", attributes: [
            .font: UIFont(name: Typography.font, size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: Palette.gold,
            .kern: 4,
        ])
        title.verticalAlignmentMode = .center
        title.alpha = 0.5
        title.position = CGPoint(x: 0, y: h / 2 - 68)
        addChild(title)

        addChild(container)
        let state = flow.state
        let ids = flow.levels.availableLevelIDs().sorted()
        let top = h / 2 - 130
        for (i, id) in ids.enumerated() {
            let name = (try? flow.levels.load(id: id))?.name
            let row = makeRow(id: id, name: name, state: state)
            row.position = CGPoint(x: 0, y: top - Self.rowSize.height / 2 - CGFloat(i) * (Self.rowSize.height + Self.gap))
            container.addChild(row)
            rowIDs.append((id, row, id <= state.currentLevel))
        }
        let contentHeight = CGFloat(ids.count) * Self.rowSize.height + CGFloat(max(ids.count - 1, 0)) * Self.gap
        let available = h - 130 - 56
        maxScroll = max(0, contentHeight - available)
    }

    private func makeRow(id: Int, name: String?, state: GameState) -> SKNode {
        let row = SKNode()
        row.name = "level:\(id)"
        let isCurrent = id == state.currentLevel
        let locked = id > state.currentLevel
        let bg = SKShapeNode(path: Shapes.roundedRect(Self.rowSize, corner: 12))
        bg.fillColor = UIColor(red: 0x15 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)
        bg.strokeColor = Palette.amber.withAlphaComponent(isCurrent ? 0.9 : 0.4)
        bg.lineWidth = isCurrent ? 2 : 1
        row.addChild(bg)

        let text = SKLabelNode(fontNamed: Typography.font)
        text.text = name.map { "LEVEL \(id) \u{00B7} \($0)" } ?? "LEVEL \(id)"
        text.fontSize = 15
        text.fontColor = Palette.white
        text.horizontalAlignmentMode = .left
        text.verticalAlignmentMode = .center
        text.position = CGPoint(x: -Self.rowSize.width / 2 + 16, y: 0)
        row.addChild(text)

        let tag = SKLabelNode(fontNamed: Typography.font)
        tag.text = id <= state.highestClearedLevel ? "CLEARED" : (isCurrent ? "CURRENT" : "LOCKED")
        tag.fontSize = 11
        tag.fontColor = id <= state.highestClearedLevel ? Palette.gold : Palette.white
        tag.horizontalAlignmentMode = .right
        tag.verticalAlignmentMode = .center
        tag.position = CGPoint(x: Self.rowSize.width / 2 - 16, y: 0)
        row.addChild(tag)

        if locked { row.alpha = 0.35 }
        return row
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !didLeave, !didStart, let touch = touches.first else { return }
        let p = touch.location(in: self)
        if back.contains(p) {
            didLeave = true
            flow.showHome()
            return
        }
        touchStart = p
        lastY = p.y
        totalMove = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchStart != nil, let touch = touches.first else { return }
        let y = touch.location(in: self).y
        let dy = y - lastY
        lastY = y
        totalMove += abs(dy)
        if maxScroll > 0 {
            container.position.y = min(max(container.position.y + dy, 0), maxScroll)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchStart = nil }
        guard !didStart, !didLeave, let start = touchStart, let touch = touches.first else { return }
        let end = touch.location(in: self)
        guard totalMove < 8, abs(end.x - start.x) < 8 else { return }
        let local = convert(end, to: container)
        for r in rowIDs where r.playable {
            if abs(local.x - r.node.position.x) <= Self.rowSize.width / 2,
               abs(local.y - r.node.position.y) <= Self.rowSize.height / 2 {
                didStart = true
                flow.startLevel(id: r.id)
                return
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchStart = nil }
}
