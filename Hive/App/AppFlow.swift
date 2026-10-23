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

    /// The level PLAY starts: the next uncleared level, capped at the highest level that ships.
    var playableLevel: Int { min(state.currentLevel, levels.availableLevelIDs().max() ?? 1) }

    /// True once every shipped level has been cleared.
    var allLevelsCleared: Bool { state.highestClearedLevel >= (levels.availableLevelIDs().max() ?? 0) }

    /// Loads the save (a corrupt file has already been moved aside by the store) and shows home.
    func start() {
        do {
            state = try store.load() ?? GameState()
        } catch {
            print("Hive: save unreadable, starting fresh: \(error)")
            state = GameState()
        }
        #if DEBUG
        // Screenshot hook: open a screen directly on devices where taps cannot be scripted.
        if ProcessInfo.processInfo.environment["HIVE_START_SCENE"] == "upgrades" {
            showUpgrades()
            return
        }
        #endif
        showHome()
    }

    func showHome() {
        present(HomeScene(flow: self, size: view.bounds.size))
    }

    func showUpgrades() { present(UpgradesScene(flow: self, size: view.bounds.size)) }

    func showLevelSelect() { present(LevelSelectScene(flow: self, size: view.bounds.size)) }

    /// Starting cards are applied at full HP, so heal-only cards would be wasted; epics are never free.
    private static func startingPool(from pool: [UpgradeCard]) -> [UpgradeCard] {
        pool.filter { !$0.effect.isHealOnly && $0.rarity != .epic }
    }

    func startLevel(id: Int) {
        guard let level = try? levels.load(id: id) else {
            showHome()
            return
        }
        // Level 1 keeps the hand-tuned milestone 1 pool; later levels offer what the level-curve probes assume.
        let pool = id == 1 ? UpgradeCatalog.milestone1 : UpgradeCatalog.pool(unlockedThrough: id - 1)
        let startingPool = Self.startingPool(from: pool)
        let scene = GameScene(level: level, levelId: id,
                              stats: state.upgrades.hiveStats(),
                              cardPool: pool,
                              startingCardPool: startingPool,
                              startingCardCount: state.upgrades.startingCardCount,
                              flow: self, size: view.bounds.size)
        present(scene)
    }

    func startEndless() {
        guard state.endlessUnlocked else {
            showHome()
            return
        }
        let pool = UpgradeCatalog.pool(unlockedThrough: state.highestClearedLevel)
        let startingPool = Self.startingPool(from: pool)
        let scene = GameScene(mode: .endless, provider: .endless(EndlessConfig()),
                              stats: state.upgrades.hiveStats(),
                              cardPool: pool,
                              startingCardPool: startingPool,
                              startingCardCount: state.upgrades.startingCardCount,
                              flow: self, size: view.bounds.size)
        present(scene)
    }

    /// Builds the run's result. Any phase other than `.cleared` (game over, or a run abandoned mid-play or
    /// mid-card-pick from the pause menu) counts as not cleared.
    func makeRunResult(world: World, mode: RunMode) -> RunResult {
        let levelId: Int
        switch mode {
        case .endless:
            let n = world.wavesCleared
            return RunResult.endless(runID: world.runID, wavesCleared: n,
                                     coinsEarned: CoinRules.endlessCoins(wavesCleared: n,
                                                                         multiplier: state.upgrades.coinMultiplier))
        case .story(let id):
            levelId = id
        }
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
