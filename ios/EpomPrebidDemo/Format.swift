import UIKit

/// One entry per demo screen: what it is called, what it asks the auction for, and which slot id
/// carries that ask. Names follow the industry ones a publisher already uses — MREC, mobile banner,
/// interstitial, rewarded — with the media spelled out wherever two screens would otherwise look
/// like the same thing.
enum Format: String, CaseIterable {
    // Declaration order is menu order. The screens Prebid renders come first because they fill as
    // soon as the slot ids are right; the two that hand the win to Google need line items built
    // against the hb_ keys before they show anything, so they sit last and are coloured apart.
    case bannerMrecPrebid
    case bannerMobilePrebid
    case video
    case native
    case interstitial
    case interstitialImage
    case rewarded
    case rewardedPlayable
    case bannerMrecGam
    case banner320Gam

    var title: String {
        switch self {
        case .bannerMrecPrebid:  return "MREC 300x250 — Prebid renders"
        case .bannerMobilePrebid: return "Mobile banner 320x50 — Prebid renders"
        case .video:             return "In-banner video"
        case .native:            return "Native"
        case .interstitial:      return "Interstitial video"
        case .interstitialImage: return "Interstitial image"
        case .rewardedPlayable:  return "Rewarded playable"
        case .rewarded:          return "Rewarded video"
        case .bannerMrecGam:     return "MREC 300x250 — Google renders"
        case .banner320Gam:      return "Mobile banner 320x50 — Google renders"
        }
    }

    var subtitle: String {
        switch self {
        case .bannerMrecPrebid:  return "Prebid draws the winning creative. No Google ad unit, no line item."
        case .bannerMobilePrebid: return "The size most apps sell, on the same slot the Google one uses."
        case .video:             return "VAST inside a 320x240 slot. Prebid plays it."
        case .native:            return "The bid returns assets; the app draws the ad in its own style."
        case .interstitial:      return "Full screen video, on a slot marked instl."
        case .interstitialImage: return "Full screen image or HTML, on a slot of its own."
        case .rewardedPlayable:  return "Full screen HTML. The creative says when the reward is earned."
        case .rewarded:          return "Full screen video. The reward arrives when it completes."
        case .bannerMrecGam:     return "Needs a Google ad unit and a line item on the hb_ keys."
        case .banner320Gam:      return "Needs its own ad unit — an MREC line item will not fill it."
        }
    }

    /// Whether the win is handed to Google Ad Manager to render, rather than drawn by Prebid.
    var rendersThroughGoogle: Bool {
        switch self {
        case .bannerMrecGam, .banner320Gam: return true
        default:                            return false
        }
    }

    /// What this screen asks the auction for, named in its first log line. It is the whole
    /// difference between the screens, so it is worth saying out loud rather than leaving the
    /// reader to infer it from the title.
    var requestNoun: String {
        switch self {
        case .interstitial:      return "full-screen video"
        case .interstitialImage: return "full-screen image"
        case .rewardedPlayable:  return "rewarded playable"
        case .rewarded:          return "rewarded video"
        case .video:             return "VAST video"
        case .native:            return "native ad"
        default:                 return "\(Int(size.width))x\(Int(size.height)) banner"
        }
    }

    var size: CGSize {
        switch self {
        case .banner320Gam, .bannerMobilePrebid: return CGSize(width: 320, height: 50)
        case .video:        return CGSize(width: 320, height: 240)
        default:            return CGSize(width: 300, height: 250)
        }
    }

    /// The Google ad unit this screen loads. Only the two Google-rendered screens have one, and
    /// they are different units: line items built for an MREC do not fill a mobile banner.
    var gamAdUnit: String {
        switch self {
        case .banner320Gam: return Settings.adUnitBanner
        default:            return Settings.adUnitMREC
        }
    }

    /// Whether the screen has everything it needs to be worth opening. A Google-rendered screen
    /// without an ad unit of its own reaches nothing and shows nothing, and a menu entry that can
    /// only disappoint is worse than no entry: the menu hides these until Settings names a unit.
    var isReady: Bool {
        guard rendersThroughGoogle else { return true }
        let unit = gamAdUnit.trimmingCharacters(in: .whitespaces)
        return !unit.isEmpty && unit != Config.gamAdUnitMREC && unit != Config.gamAdUnitBanner
    }

    var configId: String {
        switch self {
        case .banner320Gam, .bannerMobilePrebid: return Settings.configIdBanner
        case .interstitial:      return Settings.configIdInterstitial
        case .interstitialImage: return Settings.configIdInterstitialImage
        case .rewardedPlayable:  return Settings.configIdPlayable
        case .rewarded:          return Settings.configIdRewarded
        case .video:             return Settings.configIdVideo
        case .native:            return Settings.configIdNative
        default:                 return Settings.configIdMREC
        }
    }
}

enum Brand {
    static let blue = UIColor(red: 0x52 / 255, green: 0x73 / 255, blue: 0xEF / 255, alpha: 1)
    /// The Google-rendered screens. Far enough from the blue to read as a different family at a
    /// glance, which is the point: those two behave differently and fail differently.
    static let google = UIColor(red: 0x0D / 255, green: 0x94 / 255, blue: 0x88 / 255, alpha: 1)
    static let navy = UIColor(red: 0x06 / 255, green: 0x00 / 255, blue: 0x28 / 255, alpha: 1)
    static let muted = UIColor(red: 0xB9 / 255, green: 0xC2 / 255, blue: 0xE8 / 255, alpha: 1)
}
