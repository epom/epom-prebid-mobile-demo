import AppTrackingTransparency
import GoogleMobileAds
import PrebidMobile
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        MobileAds.shared.start(completionHandler: nil)

        // Prebid talks to a Prebid Server, never to Epom directly. Epom is reached as a bidder,
        // server side, by the epom_as adapter — which is why nothing here names Epom except the
        // two parameters that adapter needs.
        Prebid.shared.prebidServerAccountId = Settings.accountId
        // The rendering API caches bids for display and marks the winner from hb_pb / hb_bidder;
        // these switch that on. The server also sends the same targeting defaults, but the SDK
        // still needs its own cache enabled or only inline creatives (a playable) render.
        Prebid.shared.includeWinners = true
        Prebid.shared.includeBidderKeys = true
        // Both the throw and the status are surfaced on purpose. Swallowing them with `try?` and an
        // empty closure leaves an app that simply never bids and says nothing about why — which is
        // the single most confusing way this integration can fail.
        do {
            try Prebid.initializeSDK(
                serverURL: Settings.serverURL,
                gadMobileAdsVersion: String(MobileAds.shared.versionNumber.majorVersion)
            ) { status, error in
                NSLog("EpomPrebidDemo: %@", "prebid sdk: \(status)" + (error.map { " — \($0.localizedDescription)" } ?? ""))
            }
        } catch {
            NSLog("EpomPrebidDemo: %@", "prebid sdk refused the server url: \(error.localizedDescription)")
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController(rootViewController: MenuViewController())
        if ProcessInfo.processInfo.arguments.contains("-openRenderer") {
            nav.pushViewController(AdViewController(format: .bannerMrecPrebid), animated: false)
        }
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Asked once, after the first frame, because iOS refuses the prompt before then. Declining
        // is not a failure: the advertising id comes back all zeros, the SDK sends the vendor id in
        // its place, and capping keeps working on that instead.
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
