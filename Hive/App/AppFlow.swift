import SpriteKit
import UIKit
import HiveCore

/// Owns the persistent game state and the ad provider, and moves between scenes. The only app file that reads the
/// wall clock or calls `ads.show*`; scenes read ad availability through `reviveAllowed` / `rewardedReady` (M4 R27).
final class AppFlow {
    let view: SKView
    let levels: LevelLoader
    /// `RootViewController`: what ads and the consent prompts are presented from (R22).
    let presenter: UIViewController
    let ads: AdProviding
    private let store: SaveStore
    private(set) var state = GameState()
    /// True once `ads.start` completed successfully; every ad gate and `reviveAllowed` hang off it.
    private(set) var adsStarted = false
    private var adsStarting = false

    init(view: SKView, store: SaveStore, levels: LevelLoader, presenter: UIViewController, ads: AdProviding) {
        self.view = view
        self.store = store
        self.levels = levels
        self.presenter = presenter
        self.ads = ads
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
        // Consent already ran once: start the SDK (UMP re-prompts only if it must). Deferred one turn because the
        // root view is not yet in the window during `willConnectTo`.
        if state.consentPrompted {
            DispatchQueue.main.async { [weak self] in self?.startAds() }
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
        // The one re-arm point a run can reach after a failed load (every show is gated on readiness); a no-op
        // while a load is in flight.
        if adsStarted { ads.preload() }
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
        if adsStarted { ads.preload() }
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
                                                                         multiplier: state.upgrades.coinMultiplier),
                                     revived: world.reviveUsed)
        case .story(let id):
            levelId = id
        }
        let cleared = world.phase == .cleared
        let totalWaves = world.director.totalWaves
        let wavesCleared = cleared ? totalWaves : max(0, world.director.waveNumber - 1)
        let coins = CoinRules.coins(levelId: levelId, wavesCleared: wavesCleared, cleared: cleared,
                                    multiplier: state.upgrades.coinMultiplier)
        return RunResult(runID: world.runID, levelId: levelId, cleared: cleared,
                         wavesCleared: wavesCleared, totalWaves: totalWaves, coinsEarned: coins,
                         revived: world.reviveUsed)
    }

    /// Records the run once (idempotent by run id) and saves immediately when it counted. The first recorded story
    /// run end also triggers the consent flow (R21) on the next run-loop turn, after `GameScene` has added the
    /// `EndOverlay` in this same frame, so the prompts appear over the results card.
    func runEnded(_ result: RunResult) {
        if state.record(result) { save() }
        if AdRules.shouldPromptConsent(state, after: result) {
            state.consentPrompted = true
            save()
            DispatchQueue.main.async { [weak self] in self?.startAds() }
        }
    }

    @discardableResult
    func purchase(_ track: UpgradeTrack) -> Bool {
        guard state.purchase(track) else { return false }
        save()
        return true
    }

    // MARK: Ads (M4)

    /// Runs the provider's consent → ATT → SDK start chain once; the provider preloads itself on success.
    func startAds() {
        guard !adsStarted, !adsStarting else { return }
        adsStarting = true
        ads.start(from: presenter) { [weak self] ok in
            self?.adsStarting = false
            self?.adsStarted = ok
        }
    }

    /// World may enter `.downed` instead of `.gameOver` only once the ad system is up (R3); whether an ad is
    /// actually loaded is checked at that moment through `rewardedReady`.
    var reviveAllowed: Bool { adsStarted }

    /// A rewarded ad can be presented right now; overlays add their rewarded controls only when this is true (R25).
    var rewardedReady: Bool { adsStarted && ads.isRewardedReady }

    /// Presents the loaded rewarded ad. `onDismiss` runs exactly once, after `onReward` if granted — at once when
    /// no ad is ready. The 90 s interstitial cooldown starts whenever a rewarded ad was actually shown, granted or not.
    func showRewarded(onReward: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        guard rewardedReady else {
            onDismiss()
            return
        }
        ads.showRewarded(from: presenter, onReward: onReward, onDismiss: { [weak self] in
            if let self = self {
                AdRules.noteRewardedShown(&self.state, now: Date().timeIntervalSince1970)
                self.save()
            }
            onDismiss()
        })
    }

    /// True when an interstitial is loaded and the 3 / 3 / 90 s rule allows one (R12–R14).
    func interstitialPermitted(now: TimeInterval) -> Bool {
        adsStarted && ads.isInterstitialReady && AdRules.mayShowInterstitial(state, now: now)
    }

    /// Shows an interstitial when permitted and navigates on its dismiss; navigates at once otherwise. The slot is
    /// consumed when the show is requested, so a failed present yields fewer ads, never more (R12).
    func showInterstitialIfPermitted(then navigate: @escaping () -> Void) {
        guard interstitialPermitted(now: Date().timeIntervalSince1970) else { return navigate() }
        AdRules.noteInterstitialShown(&state)
        save()
        ads.showInterstitial(from: presenter, onDismiss: navigate)
    }

    /// Pays the double-coins bonus for a recorded run once (R20) and saves when it counted.
    @discardableResult
    func awardBonus(_ result: RunResult) -> Bool {
        let ok = state.awardBonus(runID: result.runID, coins: result.coinsEarned)
        if ok { save() }
        return ok
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
