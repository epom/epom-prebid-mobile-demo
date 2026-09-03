import Foundation

/// Everything the demo lets you change on the device. Defaults are the values in Config, overrides
/// live in UserDefaults, so a fresh install behaves exactly as the repository describes.
///
/// The Google application id is deliberately absent. The Mobile Ads SDK reads it from Info.plist
/// while the app starts, before any of our code runs, so it cannot be a runtime setting.
enum Settings {

    private static let store = UserDefaults.standard

    static var serverURL: String {
        get { value("server_url", Config.prebidServerURL) }
        set { store.set(newValue, forKey: "server_url") }
    }

    static var accountId: String {
        get { value("account_id", Config.prebidAccountId) }
        set { store.set(newValue, forKey: "account_id") }
    }

    static var configIdMREC: String {
        get { value("config_mrec", Config.configIdMREC) }
        set { store.set(newValue, forKey: "config_mrec") }
    }

    static var configIdBanner: String {
        get { value("config_banner", Config.configIdBanner) }
        set { store.set(newValue, forKey: "config_banner") }
    }

    static var configIdVideo: String {
        get { value("config_video", Config.configIdVideo) }
        set { store.set(newValue, forKey: "config_video") }
    }

    static var configIdNative: String {
        get { value("config_native", Config.configIdNative) }
        set { store.set(newValue, forKey: "config_native") }
    }

    static var configIdInterstitial: String {
        get { value("config_interstitial", Config.configIdInterstitial) }
        set { store.set(newValue, forKey: "config_interstitial") }
    }

    static var configIdInterstitialImage: String {
        get { value("config_interstitial_image", Config.configIdInterstitialImage) }
        set { store.set(newValue, forKey: "config_interstitial_image") }
    }

    static var configIdPlayable: String {
        get { value("config_playable", Config.configIdPlayable) }
        set { store.set(newValue, forKey: "config_playable") }
    }

    static var configIdRewarded: String {
        get { value("config_rewarded", Config.configIdRewarded) }
        set { store.set(newValue, forKey: "config_rewarded") }
    }

    static var adUnitMREC: String {
        get { value("ad_unit", Config.gamAdUnitMREC) }
        set { store.set(newValue, forKey: "ad_unit") }
    }

    static var adUnitBanner: String {
        get { value("ad_unit_banner", Config.gamAdUnitBanner) }
        set { store.set(newValue, forKey: "ad_unit_banner") }
    }

    static var googleApplicationId: String {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? "—"
    }

    static func reset() {
        ["server_url", "account_id", "config_mrec", "config_banner", "config_video", "config_native",
         "config_interstitial", "config_interstitial_image", "config_playable", "config_rewarded",
         "ad_unit", "ad_unit_banner"]
            .forEach(store.removeObject(forKey:))
    }

    /// Whether a value is still the placeholder the repository ships. A screen asks for nothing
    /// until its own id is filled in, which is better than an opaque SDK error.
    static func isPlaceholder(_ value: String) -> Bool {
        value.contains("YOUR-")
    }

    private static func value(_ key: String, _ fallback: String) -> String {
        let stored = store.string(forKey: key)?.trimmingCharacters(in: .whitespaces)
        return (stored?.isEmpty == false ? stored! : fallback)
    }
}
