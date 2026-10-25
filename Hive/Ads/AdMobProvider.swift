#if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// Real `AdProviding` on Google Mobile Ads v12 with UMP v3 consent and ATT (M4 R22–R26). Every SDK name here is
/// verified on the Mac (Task 11). Compiled only when both packages resolved, so the app still builds without them
/// (`SceneDelegate.makeAdProvider` then falls back to `NoAdsProvider`).
final class AdMobProvider: NSObject, AdProviding, FullScreenContentDelegate {
    private let ids: AdUnitIDs
    /// Set once `MobileAds.shared.start` completed; nothing reads as ready before that.
    private var started = false
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var loadingRewarded = false
    private var loadingInterstitial = false
    private var retryScheduled = false
    /// Handlers of the ad being shown; `finish()` runs the dismiss handler once and clears both.
    private var rewardHandler: (() -> Void)?
    private var dismissHandler: (() -> Void)?

    init(ids: AdUnitIDs) {
        self.ids = ids
        super.init()
    }

    var isRewardedReady: Bool { started && rewarded != nil }
    var isInterstitialReady: Bool { started && interstitial != nil }

    // MARK: Consent → ATT → SDK start (R22)

    func start(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        let params = RequestParameters()
        params.isTaggedForUnderAgeOfConsent = false
        #if DEBUG
        // `HIVE_UMP_DEBUG_EEA=1` forces the EEA form on the simulator (Task 11 §4).
        if ProcessInfo.processInfo.environment["HIVE_UMP_DEBUG_EEA"] == "1" {
            let debug = DebugSettings()
            debug.geography = .EEA
            params.debugSettings = debug
        }
        #endif
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] error in
            // A UMP error is not fatal here: `canRequestAds` decides in `startSDKIfAllowed`.
            if let error = error { print("Hive: consent flow error (info update): \(error)") }
            ConsentForm.loadAndPresentIfRequired(from: presenter) { [weak self] error in
                if let error = error { print("Hive: consent flow error (form): \(error)") }
                guard let self = self else { return completion(false) }
                self.requestTrackingIfNeeded { [weak self] in
                    guard let self = self else { return completion(false) }
                    self.startSDKIfAllowed(completion)
                }
            }
        }
    }

    /// Asks for tracking authorisation once (iOS shows the alert only while `.notDetermined`); `then` runs on main.
    private func requestTrackingIfNeeded(_ then: @escaping () -> Void) {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async(execute: then)
            }
        } else {
            then()
        }
    }

    /// Starts the SDK when UMP allows ad requests, tags the audience (R26) and preloads; `completion(false)` otherwise.
    private func startSDKIfAllowed(_ completion: @escaping (Bool) -> Void) {
        guard ConsentInformation.shared.canRequestAds else {
            print("Hive: ads not started: consent does not allow ad requests")
            return completion(false)
        }
        let config = MobileAds.shared.requestConfiguration
        config.tagForChildDirectedTreatment = false
        config.tagForUnderAgeOfConsent = false
        config.maxAdContentRating = .teen
        #if DEBUG
        // The simulator is a test device by default; a physical device's hashed id (printed by the SDK on its
        // first request) goes here.
        config.testDeviceIdentifiers = []
        #endif
        MobileAds.shared.start { [weak self] _ in
            guard let self = self else { return completion(false) }
            self.started = true
            self.preload()
            completion(true)
        }
    }

    // MARK: Loading

    /// Loads whichever placement is nil and not loading. Reached from `start`, from every dismiss, from the 30 s
    /// retry and from `AppFlow` at each run start; the `loading*` flags make overlapping calls no-ops.
    func preload() {
        guard started else { return }   // no ad loads before consent and SDK start
        if rewarded == nil && !loadingRewarded {
            loadingRewarded = true
            RewardedAd.load(with: ids.rewarded, request: Request()) { [weak self] ad, error in
                guard let self = self else { return }
                self.loadingRewarded = false
                self.rewarded = ad
                ad?.fullScreenContentDelegate = self
                if ad == nil {
                    // Error or no fill: nothing is shown; the retry re-arms the slot.
                    print("Hive: rewarded ad failed to load: \(error?.localizedDescription ?? "no fill")")
                    self.scheduleRetry()
                }
            }
        }
        if interstitial == nil && !loadingInterstitial {
            loadingInterstitial = true
            InterstitialAd.load(with: ids.interstitial, request: Request()) { [weak self] ad, error in
                guard let self = self else { return }
                self.loadingInterstitial = false
                self.interstitial = ad
                ad?.fullScreenContentDelegate = self
                if ad == nil {
                    print("Hive: interstitial failed to load: \(error?.localizedDescription ?? "no fill")")
                    self.scheduleRetry()
                }
            }
        }
    }

    /// After a failed load, one more `preload()` 30 s later (one timer at a time), so a failure right after
    /// consent cannot leave every placement hidden until relaunch.
    private func scheduleRetry() {
        guard !retryScheduled else { return }
        retryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.retryScheduled = false
            self?.preload()
        }
    }

    // MARK: Showing

    func showRewarded(from presenter: UIViewController, onReward: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        guard let ad = rewarded else { return onDismiss() }
        rewarded = nil   // a second tap cannot re-present it
        var granted = false
        rewardHandler = {
            guard !granted else { return }
            granted = true
            onReward()
        }
        dismissHandler = { [weak self] in
            onDismiss()
            self?.preload()
        }
        ad.present(from: presenter) { [weak self] in self?.rewardHandler?() }
    }

    func showInterstitial(from presenter: UIViewController, onDismiss: @escaping () -> Void) {
        guard let ad = interstitial else { return onDismiss() }
        interstitial = nil
        dismissHandler = { [weak self] in
            onDismiss()
            self?.preload()
        }
        ad.present(from: presenter)
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Hive: ad failed to present: \(error)")
        finish()
    }

    /// Runs the pending dismiss handler exactly once and clears both handlers.
    private func finish() {
        let dismiss = dismissHandler
        dismissHandler = nil
        rewardHandler = nil
        dismiss?()
    }
}
#endif
