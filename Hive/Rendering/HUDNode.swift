import SpriteKit

final class HUDNode: SKNode {
    private let hpFill = SKSpriteNode(color: Palette.gold, size: CGSize(width: 220, height: 8))
    private let nectarFill = SKSpriteNode(color: Palette.amber, size: CGSize(width: 10, height: 6))
    private let waveLabel = SKLabelNode(fontNamed: Typography.font)
    private let coinsLabel = SKLabelNode(fontNamed: Typography.font)
    private let hpWidth: CGFloat = 220
    private let nectarWidth: CGFloat

    init(viewSize: CGSize) {
        nectarWidth = viewSize.width - 64
        super.init()
        zPosition = 100

        let top = viewSize.height / 2
        let bottom = -viewSize.height / 2

        let hpTrack = SKSpriteNode(color: Palette.burntOrange, size: CGSize(width: hpWidth, height: 8))
        hpTrack.alpha = 0.3
        hpTrack.position = CGPoint(x: 0, y: top - 60)
        addChild(hpTrack)

        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(x: -hpWidth / 2, y: top - 60)
        hpFill.zPosition = 1
        addChild(hpFill)

        waveLabel.fontSize = Typography.body
        waveLabel.fontColor = Palette.gold
        waveLabel.alpha = 0.85
        waveLabel.verticalAlignmentMode = .center
        waveLabel.position = CGPoint(x: 0, y: top - 84)
        addChild(waveLabel)

        // Provisional coins for this run, top-left, level with the HP bar.
        coinsLabel.fontSize = 14
        coinsLabel.fontColor = Palette.gold
        coinsLabel.horizontalAlignmentMode = .left
        coinsLabel.verticalAlignmentMode = .center
        coinsLabel.position = CGPoint(x: -viewSize.width / 2 + 20, y: top - 60)
        addChild(coinsLabel)

        let nectarY = bottom + 48
        let nectarTrack = SKSpriteNode(color: Palette.burntOrange, size: CGSize(width: nectarWidth, height: 6))
        nectarTrack.alpha = 0.3
        nectarTrack.position = CGPoint(x: 0, y: nectarY)
        addChild(nectarTrack)

        nectarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        nectarFill.position = CGPoint(x: -nectarWidth / 2, y: nectarY)
        nectarFill.zPosition = 1
        addChild(nectarFill)

        // Pause control: invisible 44×44 hit area holding two vertical bars.
        let pause = SKSpriteNode(color: .clear, size: CGSize(width: 44, height: 44))
        pause.name = "pause"
        pause.position = CGPoint(x: viewSize.width / 2 - 24, y: top - 28)
        addChild(pause)
        for dx in [-5.0, 5.0] as [CGFloat] {   // bars 4 wide, 6 apart
            let bar = SKShapeNode(rect: CGRect(x: dx - 2, y: -8, width: 4, height: 16))
            bar.fillColor = Palette.gold
            bar.strokeColor = .clear
            bar.alpha = 0.85
            pause.addChild(bar)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func update(hp: Double, maxHP: Double, wave: Int, totalWaves: Int?, best: Int?, isBoss: Bool,
                nectar: Int, nectarThreshold: Int, coinsPending: Int) {
        let hpFrac = maxHP > 0 ? CGFloat(max(0, min(1, hp / maxHP))) : 0
        hpFill.size.width = hpWidth * hpFrac
        hpFill.color = hpFrac < 0.25 ? Palette.white : Palette.gold

        coinsLabel.text = "+\(coinsPending) \u{25C6}"
        if let totalWaves = totalWaves {
            waveLabel.text = isBoss ? "BOSS" : "WAVE \(wave) / \(totalWaves)"
        } else if isBoss {
            waveLabel.text = "BOSS \u{00B7} WAVE \(wave)"
        } else if let best = best, best > 0 {
            waveLabel.text = "WAVE \(wave) \u{00B7} BEST \(best)"
        } else {
            waveLabel.text = "WAVE \(wave)"
        }

        let nFrac = nectarThreshold > 0 ? CGFloat(max(0, min(1, Double(nectar) / Double(nectarThreshold)))) : 0
        nectarFill.size.width = nectarWidth * nFrac
    }
}
