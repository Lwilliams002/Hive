import SpriteKit

final class GameScene: SKScene {
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
    }
}
