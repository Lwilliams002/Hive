import UIKit
import SpriteKit
import HiveCore

/// Owns the window and the app flow for the single window scene.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var flow: AppFlow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let root = RootViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window

        let skView = root.skView
        skView.frame = window.bounds
        let flow = AppFlow(view: skView, store: FileSaveStore(directory: Self.saveDirectory()), levels: LevelLoader())
        self.flow = flow
        flow.start()
    }

    private static func saveDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Hive", isDirectory: true)
    }
}

/// Plain view controller whose view is the game's `SKView`.
final class RootViewController: UIViewController {
    var skView: SKView {
        loadViewIfNeeded()
        return view as! SKView
    }

    override func loadView() {
        let skView = SKView(frame: UIScreen.main.bounds)
        skView.ignoresSiblingOrder = true
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif
        view = skView
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
