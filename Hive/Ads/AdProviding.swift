import UIKit

/// The app's view of an ad SDK (M4 R27). `AppFlow` owns the one instance and is the only caller of `show*`;
/// scenes read availability only through `AppFlow`. Contract every conformer honours:
/// - `start(from:completion:)`: `completion(true)` means the SDK started and ads may be requested (consent and
///   tracking prompts have run); `completion(false)` means nothing will be ready this launch.
/// - Every callback runs on the main queue.
/// - `onReward` runs at most once per `show*` call and only when the SDK grants the reward.
/// - `onDismiss` runs exactly once per `show*` call, after `onReward` if any, also when nothing could be
///   presented — then it may run synchronously, so callers set their pending state before calling.
protocol AdProviding: AnyObject {
    /// A rewarded ad is loaded and can be presented now.
    var isRewardedReady: Bool { get }
    /// An interstitial is loaded and can be presented now.
    var isInterstitialReady: Bool { get }
    /// Runs consent, tracking authorisation and SDK start from `presenter`, then preloads.
    func start(from presenter: UIViewController, completion: @escaping (Bool) -> Void)
    /// Loads whichever placement is neither loaded nor loading; a no-op while a load is in flight.
    func preload()
    func showRewarded(from presenter: UIViewController, onReward: @escaping () -> Void, onDismiss: @escaping () -> Void)
    func showInterstitial(from presenter: UIViewController, onDismiss: @escaping () -> Void)
}
