import SpriteKit
import HiveCore

/// Owns the persistent game state and moves between scenes.
final class AppFlow {
    let view: SKView
    let levels: LevelLoader
    private let store: SaveStore
    private(set) var state = GameState()

    init(view: SKView, store: SaveStore, levels: LevelLoader) {
        self.view = view
        self.store = store
        self.levels = levels
    }

    /// Loads the save (a corrupt file has already been moved aside by the store) and shows home.
    func start() {
        do {
            state = try store.load() ?? GameState()
        } catch {
            print("Hive: save unreadable, starting fresh: \(error)")
            state = GameState()
        }
        showHome()
    }

    func showHome() {
        present(HomeScene(flow: self, size: view.bounds.size))
    }

    /// Placeholder until the upgrades screen exists.
    func showUpgrades() { present(PlaceholderScene(title: "UPGRADES", flow: self, size: view.bounds.size)) }

    /// Placeholder until the level-select screen exists.
    func showLevelSelect() { present(PlaceholderScene(title: "LEVELS", flow: self, size: view.bounds.size)) }

    func startLevel(id: Int) {
        guard let level = try? levels.load(id: id) else {
            showHome()
            return
        }
        let scene = GameScene(level: level, levelId: id,
                              stats: state.upgrades.hiveStats(),
                              cardPool: UpgradeCatalog.milestone1,
                              startingCardCount: state.upgrades.startingCardCount,
                              flow: self, size: view.bounds.size)
        present(scene)
    }

    func makeRunResult(world: World, levelId: Int) -> RunResult {
        let cleared = world.phase == .cleared
        let totalWaves = world.director.totalWaves
        let wavesCleared = cleared ? totalWaves : max(0, world.director.waveNumber - 1)
        let coins = CoinRules.coins(levelId: levelId, wavesCleared: wavesCleared, cleared: cleared,
                                    multiplier: state.upgrades.coinMultiplier)
        return RunResult(runID: world.runID, levelId: levelId, cleared: cleared,
                         wavesCleared: wavesCleared, totalWaves: totalWaves, coinsEarned: coins)
    }

    /// Records the run once (idempotent by run id) and saves immediately when it counted.
    func runEnded(_ result: RunResult) {
        if state.record(result) { save() }
    }

    @discardableResult
    func purchase(_ track: UpgradeTrack) -> Bool {
        guard state.purchase(track) else { return false }
        save()
        return true
    }

    private func save() {
        do {
            try store.save(state)
        } catch {
            print("Hive: save failed: \(error)")
        }
    }

    private func present(_ scene: SKScene) {
        scene.scaleMode = .resizeFill
        if view.scene == nil {
            view.presentScene(scene)
        } else {
            view.presentScene(scene, transition: .fade(withDuration: 0.3))
        }
    }
}
