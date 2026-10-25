import Foundation

/// Ad unit ids (M4 R23). DEBUG builds always use Google's published test units; a release build reads
/// `AdConfig.plist` (gitignored; xcodegen bundles it only when present) and falls back to the test units when the
/// file or a key is absent. The App ID itself lives in `Info.plist`, where the SDK needs it at start.
struct AdUnitIDs {
    let rewarded: String
    let interstitial: String

    /// Google's test units: rewarded and interstitial.
    static let test = AdUnitIDs(rewarded: "ca-app-pub-3940256099942544/1712485313",
                                interstitial: "ca-app-pub-3940256099942544/4411468910")

    static func load(bundle: Bundle = .main) -> AdUnitIDs {
        #if DEBUG
        return .test
        #else
        guard let url = bundle.url(forResource: "AdConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let any = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let plist = any as? [String: Any],
              let rewarded = plist["RewardedAdUnitID"] as? String,
              let interstitial = plist["InterstitialAdUnitID"] as? String else {
            return .test
        }
        return AdUnitIDs(rewarded: rewarded, interstitial: interstitial)
        #endif
    }
}
