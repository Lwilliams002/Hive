import UIKit

/// Fake `AdProviding`: inert in release and in any DEBUG run without `HIVE_FAKE_ADS`, so every placement stays
/// hidden. With `HIVE_FAKE_ADS=grant` or `=cancel` (DEBUG only) it pretends the SDK started and an ad is always
/// ready, presents nothing and answers after 0.5 s, granting the reward or not — how Task 11 walks every runtime
/// path without a network. Honours the `AdProviding` contract: `onDismiss` exactly once per `show*` call.
final class NoAdsProvider: AdProviding {
    #if DEBUG
    /// `HIVE_FAKE_ADS=grant` grants every rewarded ad; `cancel` dismisses without the reward.
    enum DebugMode {
        case grant, cancel

        init?(environment: [String: String]) {
            switch environment["HIVE_FAKE_ADS"] {
            case "grant": self = .grant
            case "cancel": self = .cancel
            default: return nil
            }
        }
    }
    #endif

    /// Seconds a fake ad "plays" before its callbacks run.
    private static let fakeAdDuration: TimeInterval = 0.5
    /// True in a DEBUG fake mode: `start` succeeds and both placements read as ready.
    private let fakesAds: Bool
    /// True in `.grant`: the fake rewarded ad calls `onReward` before `onDismiss`.
    private let grantsReward: Bool

    #if DEBUG
    init(debug: DebugMode? = nil) {
        fakesAds = debug != nil
        grantsReward = debug == .grant
    }
    #else
    init() {
        fakesAds = false
        grantsReward = false
    }
    #endif

    var isRewardedReady: Bool { fakesAds }
    var isInterstitialReady: Bool { fakesAds }

    func start(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        completion(fakesAds)
    }

    func preload() {}

    func showRewarded(from presenter: UIViewController, onReward: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        guard fakesAds else { return onDismiss() }
        let grants = grantsReward
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fakeAdDuration) {
            if grants { onReward() }
            onDismiss()
        }
    }

    func showInterstitial(from presenter: UIViewController, onDismiss: @escaping () -> Void) {
        guard fakesAds else { return onDismiss() }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fakeAdDuration, execute: onDismiss)
    }
}
