import Foundation

/// Everything a publisher has to change lives in this file. Nothing else in the app needs editing.
///
/// Every value here is only the STARTING value. The Settings screen writes over each of them on the
/// device, so you can point the app at your own server and slots without rebuilding it — useful when
/// the person trying it is not the person who can compile it. "Reset" there puts these values back.
///
/// Fill them in this order; each step is testable on its own before the next one matters.
///
///   1. `prebidServerURL` + `prebidAccountId` — where the auction runs. The defaults point at the
///      Prebid Server Epom runs and its test network; a publisher on their own server replaces both.
///   2. `configId*` — one per slot, and the piece most often misunderstood. See below.
///   3. `gamAdUnit*` — only for the two screens that render through Google. The screens that say
///      "Prebid renders" ignore these entirely, which is why they fill on a fresh setup.
enum Config {

    // MARK: - 1. The auction

    /// Full URL of the auction endpoint, including the path.
    static let prebidServerURL = "https://pbs.eashb.com/openrtb2/auction"

    /// The account on that server — for Epom's server, your network id.
    static let prebidAccountId = "n2494"

    // MARK: - 2. The slots

    /// A config id is a **Prebid Server stored-request id — NOT an Epom placement key.** This trips
    /// up almost everyone, so it is worth being blunt: the app never sends your Epom placement to
    /// anyone. It sends this id; Prebid Server looks up the stored request filed under it, and THAT
    /// is where your Epom host and placement key live. Wrong id means no bid and no error worth the
    /// name — the auction simply comes back empty.
    ///
    /// The stored-request JSON to file on your server is in the README.
    static let configIdMREC = "n2494-1"
    static let configIdBanner = "n2494-12"
    static let configIdVideo = "n2494-3"
    static let configIdNative = "n2494-2"
    static let configIdInterstitial = "n2494-4"
    /// Separate from the interstitial on purpose: an interstitial slot is usually sold as banner or
    /// video, a playable is one HTML creative the user touches. Pointing both at one slot means
    /// whichever the ad server picks decides which screen you are really looking at.
    static let configIdInterstitialImage = "n2494-6"
    static let configIdPlayable = "n2494-5"
    static let configIdRewarded = "n2494-4"

    // MARK: - 3. Google, for the two screens that use it

    /// The ad units the Google-rendered screens load. A Prebid bid reaches them through the line
    /// items you set up in Google Ad Manager against the hb_ targeting keys; without those line
    /// items Google fills from its own demand and Prebid's bid is never consulted.
    static let gamAdUnitMREC = "/YOUR-NETWORK/your-mrec-ad-unit"
    static let gamAdUnitBanner = "/YOUR-NETWORK/your-banner-ad-unit"

    // MARK: - Behaviour

    /// Seconds between refreshes. Prebid clamps this to 30–120 and pauses it while the slot is off
    /// screen, so a smaller number here does not produce a faster refresh.
    static let refreshSeconds: TimeInterval = 30
}
