import Foundation

/// Ad frequency and consent predicates (M4 R14, R21; spec §6). Pure functions over `GameState` with the clock
/// injected as `now` (unix seconds, R17): HiveCore never reads the wall clock in game logic. Showing an ad is the
/// app's job; these only say whether it may, and record that it did.
public enum AdRules {
    /// Run ends of a fresh install that are interstitial-free.
    public static let freeRunEnds = 3
    /// Minimum run ends between two interstitials.
    public static let runEndsBetweenInterstitials = 3
    /// No interstitial within this many seconds after a rewarded ad.
    public static let rewardedCooldown: TimeInterval = 90

    /// True when an interstitial may be shown at a run-end exit: past the free run ends, at least
    /// `runEndsBetweenInterstitials` run ends since the last one, and not within `rewardedCooldown` of the last
    /// rewarded ad. A clock set back (`now < lastRewardedAdAt`) gives a negative difference, i.e. still inside.
    public static func mayShowInterstitial(_ s: GameState, now: TimeInterval) -> Bool {
        s.levelsEnded > freeRunEnds
            && s.levelsEnded - s.lastInterstitialAtLevelsEnded >= runEndsBetweenInterstitials
            && (s.lastRewardedAdAt.map { now - $0 >= rewardedCooldown } ?? true)
    }

    /// Consumes the interstitial slot: the next one needs `runEndsBetweenInterstitials` more run ends.
    public static func noteInterstitialShown(_ s: inout GameState) {
        s.lastInterstitialAtLevelsEnded = s.levelsEnded
    }

    /// Starts the rewarded cooldown at `now`.
    public static func noteRewardedShown(_ s: inout GameState, now: TimeInterval) {
        s.lastRewardedAdAt = now
    }

    /// True once, after the first recorded story run end of any outcome, until `consentPrompted` is set (R21).
    /// An endless end counts as a run end but never triggers the prompt.
    public static func shouldPromptConsent(_ s: GameState, after result: RunResult) -> Bool {
        guard !s.consentPrompted, s.levelsEnded >= 1 else { return false }
        if case .story = result.mode { return true }
        return false
    }
}
