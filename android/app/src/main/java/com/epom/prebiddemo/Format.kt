package com.epom.prebiddemo

/**
 * One entry per demo screen: what it is called, what it asks the auction for, and which config id
 * carries that ask. Names follow the industry ones a publisher already uses — MREC, mobile banner,
 * interstitial, rewarded — with the media spelled out wherever two screens would otherwise look
 * like the same thing.
 *
 * Declaration order is menu order. The screens Prebid renders come first because they fill as soon
 * as the slot ids are right; the two that hand the win to Google need line items built against the
 * hb_ keys before they show anything, so they sit last and are coloured apart.
 */
enum class Format(
    val title: String,
    val subtitle: String,
    /** The win is handed to Google Ad Manager to render, rather than drawn by Prebid. */
    val rendersThroughGoogle: Boolean = false,
) {
    BANNER_MREC_PREBID(
        "MREC 300x250 — Prebid renders",
        "Prebid draws the winning creative. No Google ad unit, no line item."
    ),
    VIDEO(
        "In-banner video",
        "VAST inside a 320x240 slot. Prebid plays it."
    ),
    NATIVE(
        "Native",
        "The bid returns assets; the app draws the ad in its own style."
    ),
    INTERSTITIAL(
        "Interstitial video",
        "Full screen video, on a slot marked instl."
    ),
    INTERSTITIAL_IMAGE(
        "Interstitial image",
        "Full screen image or HTML, on a slot of its own."
    ),
    PLAYABLE(
        "Playable",
        "Full screen HTML the user can play with."
    ),
    REWARDED(
        "Rewarded video",
        "Full screen video. The reward arrives when it completes."
    ),
    BANNER_MREC_GAM(
        "MREC 300x250 — Google renders",
        "Needs a Google ad unit and a line item on the hb_ keys.",
        rendersThroughGoogle = true
    ),
    BANNER_320_GAM(
        "Mobile banner 320x50",
        "Needs its own ad unit — an MREC line item will not fill it.",
        rendersThroughGoogle = true
    );

    /** What this screen asks the auction for, named in its first log line. */
    val requestNoun: String
        get() = when (this) {
            INTERSTITIAL -> "full-screen video"
            INTERSTITIAL_IMAGE -> "full-screen image"
            PLAYABLE -> "full-screen playable"
            REWARDED -> "rewarded video"
            VIDEO -> "VAST video"
            NATIVE -> "native ad"
            BANNER_320_GAM -> "320x50 banner"
            else -> "300x250 banner"
        }

    /** Width, height of the display slot. Full-screen and native screens ignore it. */
    val size: Pair<Int, Int>
        get() = when (this) {
            BANNER_320_GAM -> 320 to 50
            VIDEO -> 640 to 480
            else -> 300 to 250
        }

    /** The config id (Prebid Server stored-request id) this screen sends, resolved on the device. */
    fun configId(settings: Settings): String = when (this) {
        BANNER_320_GAM -> settings.configIdBanner
        INTERSTITIAL -> settings.configIdInterstitial
        INTERSTITIAL_IMAGE -> settings.configIdInterstitialImage
        PLAYABLE -> settings.configIdPlayable
        REWARDED -> settings.configIdRewarded
        VIDEO -> settings.configIdVideo
        NATIVE -> settings.configIdNative
        else -> settings.configIdMrec
    }

    /** The Google ad unit this screen loads. Only the two Google-rendered screens have one. */
    fun gamAdUnit(settings: Settings): String = when (this) {
        BANNER_320_GAM -> settings.adUnitBanner
        else -> settings.adUnitMrec
    }
}
