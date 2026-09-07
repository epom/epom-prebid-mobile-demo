import GoogleMobileAds
import PrebidMobile
import UIKit

/// One format per screen. Everything it needs comes from the enum and from Config.
final class AdViewController: UIViewController {

    private let format: Format
    private let status = UILabel()
    private let adSlot = UIView()
    private var adUnit: BannerAdUnit?
    private var renderer: SelfRenderedHost?
    private var interstitial: InterstitialRenderingAdUnit?
    private var rewarded: RewardedAdUnit?
    private var fullScreenHost: FullScreenHost?
    private var nativeRequest: NativeRequest?
    private var nativeAd: PrebidMobile.NativeAd?
    private var lines: [String] = []

    init(format: Format) {
        self.format = format
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = format.title
        view.backgroundColor = .systemBackground
        layout()

        // On a fresh clone every slot id is still the placeholder the repository ships. Asking the
        // auction with it produces an opaque SDK error; naming the missing setting does not.
        guard !Settings.isPlaceholder(format.configId) else {
            report("This screen has no slot id yet.")
            report("")
            report("Open Settings and paste the Prebid Server stored-request id for this format.")
            report("Nothing is requested until then.")
            return
        }

        switch format {
        case .bannerMrecPrebid, .bannerMobilePrebid: loadThroughPrebid()
        case .video: loadVideo()
        case .native: loadNative()
        case .interstitial: loadFullScreen(video: true)
        case .interstitialImage: loadFullScreen(video: false)
        case .rewarded, .rewardedPlayable: loadRewarded()
        default: loadThroughGoogle()
        }
    }


    /// Prebid bids, Google renders - the integration a publisher running Google already has.
    private func loadThroughGoogle() {
        let banner = AdManagerBannerView(adSize: adSizeFor(cgSize: format.size))
        banner.adUnitID = format.gamAdUnit
        banner.rootViewController = self
        banner.delegate = self
        place(banner)

        let unit = BannerAdUnit(configId: format.configId, size: format.size)
        unit.setAutoRefreshMillis(time: Config.refreshSeconds * 1000)
        adUnit = unit

        let request = AdManagerRequest()
        report(opening)
        unit.fetchDemand(adObject: request) { [weak self] result in
            self?.report("Prebid Server answered: \(result.name()). Bid keys passed to Google.")
            banner.load(request)
        }
    }

    /// Prebid bids and draws it itself. No Google ad unit, no line item, so it fills on a fresh setup.
    private func loadThroughPrebid() {
        let host = SelfRenderedHost(owner: self)
        renderer = host

        let banner = PrebidMobile.BannerView(
            frame: CGRect(origin: .zero, size: format.size),
            configID: format.configId,
            adSize: format.size
        )
        // Prebid clamps this to 30-120 s and pauses it off screen, in the background, or while the
        // creative is expanded. This is the APP's setting: the refresh interval on an Epom
        // header-bidding tag governs the web runtime only and has no effect here.
        banner.refreshInterval = Config.refreshSeconds
        banner.delegate = host
        place(banner)
        report(opening)
        banner.loadAd()
    }

    /// In-banner VAST. The same renderer as the banner screen, told the slot is a video one — no
    /// Prebid Cache and no Google line item are involved, so it fills on a fresh setup.
    private func loadVideo() {
        let host = SelfRenderedHost(owner: self)
        renderer = host

        let banner = PrebidMobile.BannerView(
            frame: CGRect(origin: .zero, size: format.size),
            configID: format.configId,
            adSize: format.size
        )
        banner.adFormat = .video
        banner.videoParameters.mimes = ["video/mp4"]
        banner.refreshInterval = Config.refreshSeconds
        banner.delegate = host
        place(banner)
        report(opening)
        banner.loadAd()
    }

    /// Native comes back as assets, not as markup: Prebid hands over title, body, image and call to
    /// action, and the app draws them in its own style. That is the whole point of the format.
    private func loadNative() {
        // The image asset has to say WHICH image it is. Without `type` the request asks for an
        // untyped picture, the ad server has no main image to match it against, and the whole
        // impression comes back empty — the one difference between a filling and a silent request.
        let mainImage = NativeAssetImage(minimumWidth: 200, minimumHeight: 200, required: true)
        mainImage.type = ImageAsset.Main

        let icon = NativeAssetImage(minimumWidth: 50, minimumHeight: 50, required: false)
        icon.type = ImageAsset.Icon

        let unit = NativeRequest(configId: format.configId, assets: [
            NativeAssetTitle(length: 90, required: true),
            mainImage,
            icon,
            NativeAssetData(type: .description, required: false),
            NativeAssetData(type: .ctatext, required: false),
            NativeAssetData(type: .sponsored, required: false),
        ])
        unit.context = ContextType.Social
        unit.placementType = PlacementType.FeedContent
        nativeRequest = unit

        report(opening)
        unit.fetchDemand { [weak self] (bidInfo: BidInfo) in
            guard let self else { return }
            self.report("Prebid Server answered: \(bidInfo.resultCode.name())")
            guard bidInfo.resultCode == .prebidDemandFetchSuccess,
                  let cacheId = bidInfo.nativeAdCacheId,
                  let ad = PrebidMobile.NativeAd.create(cacheId: cacheId) else {
                self.report("The response carried no native assets — the bid has to return a title, an image and a link.")
                return
            }
            self.draw(ad)
        }
    }

    private func draw(_ ad: PrebidMobile.NativeAd) {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        card.alignment = .leading

        let title = UILabel()
        title.text = ad.title
        title.font = .boldSystemFont(ofSize: 15)
        title.numberOfLines = 2
        card.addArrangedSubview(title)

        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.heightAnchor.constraint(equalToConstant: 150).isActive = true
        image.widthAnchor.constraint(equalToConstant: format.size.width).isActive = true
        card.addArrangedSubview(image)
        if let url = ad.imageUrl.flatMap(URL.init(string:)) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let loaded = UIImage(data: data) else { return }
                DispatchQueue.main.async { image.image = loaded }
            }.resume()
        }

        let body = UILabel()
        body.text = ad.text
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabel
        body.numberOfLines = 3
        card.addArrangedSubview(body)

        let cta = UILabel()
        cta.text = ad.callToAction ?? "Learn more"
        cta.font = .boldSystemFont(ofSize: 13)
        cta.textColor = Brand.blue
        card.addArrangedSubview(cta)

        // Prebid fires the impression and click trackers off this view, so the ad has to own it.
        _ = ad.registerView(view: card, clickableViews: [cta])
        nativeAd = ad
        place(card)
        report("Assets received. The card above is drawn by the app, not by the ad server.")
    }

    /// A full-screen slot is not placed in the view tree — it is loaded, then presented over the app.
    /// `video` picks which creative type this screen asks for: a playable and an image are both
    /// asking for video as well would let an ordinary pre-roll win the slot instead.
    private func loadFullScreen(video: Bool) {
        let host = FullScreenHost(owner: self)
        fullScreenHost = host

        let unit = InterstitialRenderingAdUnit(configID: format.configId)
        // Each full-screen screen asks for the one creative type it is named after. Asking for both
        // would let the ad server decide which screen you are really looking at.
        unit.adFormats = video ? [.video] : [.banner]
        unit.delegate = host
        interstitial = unit

        report(opening)
        unit.loadAd()
    }

    /// The reward is the SDK's to grant, not ours to invent: it arrives on the delegate as a
    /// `PrebidReward`, sourced from the bid's passthrough. The app only decides what to do with it.
    private func loadRewarded() {
        let host = FullScreenHost(owner: self)
        fullScreenHost = host

        let unit = RewardedAdUnit(configID: format.configId)
        // A playable is HTML, so that screen asks for HTML alone. Asking for both would let a
        // placement that also holds a video answer with the video instead, which is not the thing
        // the screen is named after. The video screen asks for both because a rewarded video slot
        // may legitimately answer with either.
        unit.adFormats = format == .rewardedPlayable ? [.banner] : [.banner, .video]
        unit.delegate = host
        rewarded = unit

        report(opening)
        unit.loadAd()
    }

    fileprivate func present(_ show: (UIViewController) -> Void) {
        show(self)
    }

    private func place(_ ad: UIView) {
        ad.translatesAutoresizingMaskIntoConstraints = false
        adSlot.addSubview(ad)
        NSLayoutConstraint.activate([
            ad.leadingAnchor.constraint(equalTo: adSlot.leadingAnchor),
            ad.topAnchor.constraint(equalTo: adSlot.topAnchor),
            ad.widthAnchor.constraint(equalToConstant: format.size.width),
            ad.heightAnchor.constraint(equalToConstant: format.size.height),
            adSlot.heightAnchor.constraint(equalToConstant: format.size.height),
        ])
    }

    private func layout() {
        let subtitle = UILabel()
        subtitle.text = format.subtitle
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        status.numberOfLines = 0
        status.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        status.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [subtitle, adSlot, status])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }

    /// The app is the bank. It decides what the player is owed and pays it; the bid may describe a
    /// reward, and this says so when it does, but a bid that describes none is not a bid that owes
    /// nothing — an app waiting for one would never pay out at all.
    fileprivate func grantReward(describedByBid: String?) {
        report(describedByBid == nil
            ? "Reward granted: 10 Epom Coins. The bid described no reward, so the app used its own."
            : "Reward granted: 10 Epom Coins. The bid asked for \(describedByBid!).")
        showRewardBadge()
    }

    private func showRewardBadge() {
        let badge = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "+10 Epom Coins"
        config.image = UIImage(named: "EpomMark")
        config.imagePadding = 10
        config.baseBackgroundColor = Brand.navy
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 14, leading: 22, bottom: 14, trailing: 22)
        badge.configuration = config
        badge.isUserInteractionEnabled = false
        badge.alpha = 0
        badge.transform = CGAffineTransform(translationX: 0, y: 20)
        badge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badge.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
        ])
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            badge.alpha = 1
            badge.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.6) {
                badge.alpha = 0
            } completion: { _ in badge.removeFromSuperview() }
        }
    }

    /// The one line every screen opens with. Naming the slot id here is what turns "nothing
    /// happened" into "nothing happened for this id", which is the difference between a demo an
    /// evaluator can debug and one they cannot.
    private var opening: String {
        "Asking Prebid Server for a \(format.requestNoun) — slot \(format.configId)"
    }

    fileprivate func report(_ line: String) {
        lines.append(line)
        status.text = lines.joined(separator: "\n")
        NSLog("EpomPrebidDemo: %@", line)
    }
}

// Both SDKs export a `BannerView`, so every mention of Google's has to name the module. Left
// unqualified it fails with "ambiguous for type lookup", which does not say which two are clashing.
extension AdViewController: GoogleMobileAds.BannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        // Google sizes the frame for the line item, not for the creative.
        AdViewUtils.findPrebidCreativeSize(bannerView, success: { size in
            bannerView.adSize = adSizeFor(cgSize: size)
        }, failure: { _ in })
        report("Google loaded the slot.")
    }

    func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
        report("Google: \(error.localizedDescription)")
    }
}

/// Prebid's own renderer delegate lives on a separate object: both SDKs export a
/// `BannerViewDelegate`, and one class cannot usefully conform to both.
private final class SelfRenderedHost: NSObject, PrebidMobile.BannerViewDelegate {

    private weak var owner: AdViewController?

    init(owner: AdViewController) { self.owner = owner }

    func bannerViewPresentationController() -> UIViewController? { owner }

    func bannerView(_ bannerView: PrebidMobile.BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        owner?.report("Prebid rendered the winner at \(Int(adSize.width))x\(Int(adSize.height)).")
    }

    func bannerView(_ bannerView: PrebidMobile.BannerView, didFailToReceiveAdWith error: Error) {
        owner?.report("Prebid: \(error.localizedDescription)")
    }
}

/// Both full-screen ad units report through their own delegates, and neither can be folded into the
/// view controller: `RewardedAdUnitDelegate` inherits the interstitial one, so a single class would
/// have to answer for both and the reward callback would fire for plain interstitials too.
private final class FullScreenHost: NSObject, InterstitialAdUnitDelegate, RewardedAdUnitDelegate {

    private weak var owner: AdViewController?

    init(owner: AdViewController) { self.owner = owner }

    // MARK: Interstitial

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        owner?.report("Loaded. Presenting over the app.")
        owner?.present { interstitial.show(from: $0) }
    }

    func interstitial(_ interstitial: InterstitialRenderingAdUnit,
                      didFailToReceiveAdWithError error: Error?) {
        owner?.report("Prebid: \(error?.localizedDescription ?? "no ad returned")")
    }

    func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        owner?.report("Closed.")
    }

    func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        owner?.report("Clicked through.")
    }

    // MARK: Rewarded

    func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        owner?.report("Loaded. Presenting over the app.")
        owner?.present { rewardedAd.show(from: $0) }
    }

    func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        owner?.report("Prebid: \(error?.localizedDescription ?? "no ad returned")")
    }

    /// The one callback that makes rewarded different from interstitial. Whatever the app grants the
    /// user — coins, a life, an unlocked level — hangs off here and nowhere else.
    func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit, reward: PrebidReward) {
        // Two different things, and conflating them is the usual confusion. The bid may describe a
        // reward; the app is the one that grants it. Ours grants the same thing either way, and
        // says whether the bid had an opinion about it.
        let described = [reward.count?.stringValue, reward.type]
            .compactMap { $0 }
            .joined(separator: " x ")
        owner?.grantReward(describedByBid: described.isEmpty ? nil : described)
    }

    func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        owner?.report("Closed.")
    }
}
