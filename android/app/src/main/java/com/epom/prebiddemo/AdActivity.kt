package com.epom.prebiddemo

import android.os.Bundle
import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.admanager.AdManagerAdRequest
import com.google.android.gms.ads.admanager.AdManagerAdView
import org.prebid.mobile.AdSize as PrebidAdSize
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView as TV
import org.prebid.mobile.BannerAdUnit
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidNativeAd
import org.prebid.mobile.PrebidNativeAdEventListener
import org.prebid.mobile.api.data.VideoPlacementType
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.addendum.AdViewUtils
import org.prebid.mobile.addendum.PbFindSizeError
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.BannerView as PrebidBannerView
import org.prebid.mobile.api.rendering.InterstitialAdUnit
import org.prebid.mobile.api.rendering.RewardedAdUnit
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.rendering.listeners.BannerViewListener
import org.prebid.mobile.api.rendering.listeners.InterstitialAdUnitListener
import org.prebid.mobile.api.rendering.listeners.RewardedAdUnitListener
import org.prebid.mobile.rendering.interstitial.rewarded.Reward
import java.util.EnumSet

/** One format per screen. Everything it needs comes from the enum and from strings.xml. */
class AdActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_FORMAT = "format"
    }

    private val log = StringBuilder()
    private lateinit var settings: Settings

    /** Held for the lifetime of the screen: a collected ad unit never delivers its callback. */
    private val adUnits = mutableListOf<Any>()

    private lateinit var format: Format

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ad)
        settings = Settings(this)

        format = Format.valueOf(intent.getStringExtra(EXTRA_FORMAT) ?: Format.BANNER_MREC_GAM.name)
        findViewById<TextView>(R.id.title).text = format.title
        findViewById<TextView>(R.id.subtitle).text = format.subtitle
        title = format.title

        MobileAds.initialize(this)

        // Two paths, and both are needed. An ad unit created before initializeSdk finishes sends its
        // request but never receives the answer. But the callback fires once per PROCESS, so hanging
        // the load off it alone leaves a recreated activity showing nothing at all.
        if (PrebidMobile.isSdkInitialized()) {
            start()
        } else {
            PrebidMobile.setPrebidServerAccountId(settings.accountId)
            PrebidMobile.initializeSdk(applicationContext, settings.serverUrl) { status ->
                report("prebid sdk: $status")
                runOnUiThread { start() }
            }
        }
    }

    private fun start() {
        report("Asking Prebid Server for a ${format.requestNoun} — config ${format.configId(settings)}")
        when (format) {
            Format.BANNER_MREC_GAM -> loadThroughGoogle(300, 250)
            Format.BANNER_320_GAM -> loadThroughGoogle(320, 50)
            Format.BANNER_MREC_PREBID -> loadThroughPrebid(300, 250)
            Format.VIDEO -> loadVideo()
            Format.NATIVE -> loadNative()
            Format.INTERSTITIAL -> loadFullScreen(video = true)
            Format.INTERSTITIAL_IMAGE, Format.PLAYABLE -> loadFullScreen(video = false)
            Format.REWARDED -> loadRewarded()
        }
    }

    private fun container() = findViewById<FrameLayout>(R.id.adContainer)

    /** Prebid bids, Google renders — the integration a publisher running Google already has. */
    private fun loadThroughGoogle(width: Int, height: Int) {
        val adView = AdManagerAdView(this).apply {
            adUnitId = format.gamAdUnit(settings)
            setAdSizes(AdSize(width, height))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        container().addView(adView)

        val adUnit = BannerAdUnit(format.configId(settings), width, height)
        adUnit.setAutoRefreshInterval(resources.getInteger(R.integer.refresh_seconds))
        adUnits += adUnit

        adView.adListener = object : AdListener() {
            override fun onAdLoaded() {
                // Google sizes the frame for the line item, not for the creative. Without this a
                // 300x250 arrives in a 320x50 hole.
                AdViewUtils.findPrebidCreativeSize(adView, object : AdViewUtils.PbFindSizeListener {
                    override fun success(w: Int, h: Int) = adView.setAdSizes(AdSize(w, h))
                    override fun failure(error: PbFindSizeError) = Unit
                })
                report("google: loaded")
            }

            override fun onAdFailedToLoad(error: LoadAdError) = report("google: ${error.message}")
        }

        val request = AdManagerAdRequest.Builder().build()
        report("asking prebid…")
        adUnit.fetchDemand(request) { result ->
            report("prebid: $result")
            adView.loadAd(request)
        }
    }

    /** Prebid bids and draws it itself. No Google ad unit, no line item, so it fills on a fresh setup. */
    private fun loadThroughPrebid(width: Int, height: Int) {
        val banner = PrebidBannerView(this, format.configId(settings), PrebidAdSize(width, height))
        banner.setAutoRefreshDelay(resources.getInteger(R.integer.refresh_seconds))
        banner.setBannerListener(object : BannerViewListener {
            override fun onAdLoaded(view: PrebidBannerView?) = report("prebid rendered: ${width}x$height")
            override fun onAdDisplayed(view: PrebidBannerView?) = Unit
            override fun onAdFailed(view: PrebidBannerView?, e: AdException?) = report("prebid: ${e?.message}")
            override fun onAdClicked(view: PrebidBannerView?) = Unit
            override fun onAdClosed(view: PrebidBannerView?) = Unit
        })
        adUnits += banner
        container().addView(banner)
        report("asking prebid…")
        banner.loadAd()
    }

    /**
     * Outstream video, drawn by Prebid itself. The same BannerView as the display slot, told to ask
     * for VAST instead of HTML — the ad server answers imp.video and the SDK plays it.
     */
    private fun loadVideo() {
        val banner = PrebidBannerView(this, settings.configIdVideo, PrebidAdSize(640, 480))
        // This is what switches the slot to VAST — there is no separate setAdFormat. Naming the
        // placement type is the switch.
        banner.videoPlacementType = VideoPlacementType.IN_BANNER
        banner.setAutoRefreshDelay(resources.getInteger(R.integer.refresh_seconds))
        banner.setBannerListener(object : BannerViewListener {
            override fun onAdLoaded(view: PrebidBannerView?) = report("video loaded")
            override fun onAdDisplayed(view: PrebidBannerView?) = report("video displayed")
            override fun onAdFailed(view: PrebidBannerView?, e: AdException?) = report("video: ${e?.message}")
            override fun onAdClicked(view: PrebidBannerView?) = Unit
            override fun onAdClosed(view: PrebidBannerView?) = Unit
        })
        adUnits += banner
        container().addView(banner)
        report("asking prebid…")
        banner.loadAd()
    }

    /**
     * Native returns assets, not markup: a title, an image, an icon, a body and a call to action.
     * Nothing draws them for you — this screen lays them out itself, which is the whole point of the
     * format and the reason a publisher chooses it.
     */
    private fun loadNative() {
        val unit = NativeAdUnit(settings.configIdNative)
        unit.setContextType(NativeAdUnit.CONTEXT_TYPE.CONTENT_CENTRIC)
        unit.setPlacementType(NativeAdUnit.PLACEMENTTYPE.CONTENT_FEED)
        unit.setContextSubType(NativeAdUnit.CONTEXTSUBTYPE.GENERAL)

        unit.addAsset(NativeTitleAsset().apply { setLength(90); isRequired = true })
        unit.addAsset(NativeImageAsset(200, 200, 200, 200).apply {
            imageType = NativeImageAsset.IMAGE_TYPE.MAIN; isRequired = true
        })
        unit.addAsset(NativeImageAsset(20, 20, 20, 20).apply {
            imageType = NativeImageAsset.IMAGE_TYPE.ICON; isRequired = false
        })
        unit.addAsset(NativeDataAsset().apply { dataType = NativeDataAsset.DATA_TYPE.DESC; isRequired = false })
        unit.addAsset(NativeDataAsset().apply { dataType = NativeDataAsset.DATA_TYPE.CTATEXT; isRequired = false })
        unit.addAsset(NativeDataAsset().apply { dataType = NativeDataAsset.DATA_TYPE.SPONSORED; isRequired = false })
        runCatching {
            unit.addEventTracker(NativeEventTracker(
                NativeEventTracker.EVENT_TYPE.IMPRESSION,
                arrayListOf(NativeEventTracker.EVENT_TRACKING_METHOD.IMAGE)))
        }
        adUnits += unit

        report("asking prebid…")
        // The assets do not come back with the bid: the response carries a cache id, and the ad is
        // fetched from Prebid Cache by it. No cache on the server means no native, however good the bid.
        unit.fetchDemand { bidInfo ->
            report("prebid: ${bidInfo.resultCode}")
            val cacheId = bidInfo.nativeCacheId
            if (cacheId.isNullOrBlank()) {
                report("native: bid carried no cache id")
                return@fetchDemand
            }
            val ad = PrebidNativeAd.create(cacheId)
            if (ad == null) report("native: nothing in the cache for $cacheId")
            else runOnUiThread { draw(ad) }
        }
    }

    /** The assets, laid out. Deliberately plain: a publisher replaces this with their own design. */
    private fun draw(ad: PrebidNativeAd) {
        report("native rendered")
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 28, 28, 28)
            setBackgroundColor(0xFFF3F4F8.toInt())
        }
        card.addView(TV(this).apply { text = ad.title; textSize = 16f; setTypeface(null, android.graphics.Typeface.BOLD) })
        card.addView(TV(this).apply { text = ad.description; textSize = 13f; setPadding(0, 8, 0, 12) })
        val image = ImageView(this)
        card.addView(image, LinearLayout.LayoutParams(600, 400))
        card.addView(TV(this).apply { text = ad.callToAction; textSize = 13f; setTextColor(0xFF5273EF.toInt()); setPadding(0, 12, 0, 0) })
        card.addView(TV(this).apply { text = "Sponsored by ${ad.sponsoredBy}"; textSize = 11f; alpha = 0.6f })
        container().addView(card)
        // Registering the view is what fires the impression and makes the click work. Skip it and the
        // ad shows, counts nothing and does nothing.
        ad.registerView(card, listOf<android.view.View>(card), object : PrebidNativeAdEventListener {
            override fun onAdClicked() = report("native clicked")
            override fun onAdImpression() = report("native impression fired")
            override fun onAdExpired() = report("native expired")
        })
        Thread {
            runCatching {
                val bmp = android.graphics.BitmapFactory.decodeStream(java.net.URL(ad.imageUrl).openStream())
                runOnUiThread { image.setImageBitmap(bmp) }
            }
        }.start()
    }



    /**
     * Full-screen interstitial, drawn by Prebid over the whole app. Each screen asks for the one
     * creative type it is named after — video for the interstitial-video screen, banner (HTML) for
     * the image and playable ones — because asking for both would let the server decide which screen
     * you are really looking at.
     */
    private fun loadFullScreen(video: Boolean) {
        val formats = EnumSet.of(if (video) AdUnitFormat.VIDEO else AdUnitFormat.BANNER)
        val unit = InterstitialAdUnit(this, format.configId(settings), formats)
        unit.setInterstitialAdUnitListener(object : InterstitialAdUnitListener {
            override fun onAdLoaded(u: InterstitialAdUnit?) {
                report("Loaded. Presenting over the app.")
                unit.show()
            }
            override fun onAdDisplayed(u: InterstitialAdUnit?) = Unit
            override fun onAdFailed(u: InterstitialAdUnit?, e: AdException?) = report("Prebid: ${e?.message ?: "no ad returned"}")
            override fun onAdClicked(u: InterstitialAdUnit?) = report("Clicked through.")
            override fun onAdClosed(u: InterstitialAdUnit?) = report("Closed.")
        })
        adUnits += unit
        unit.loadAd()
    }

    /**
     * Rewarded, the one full-screen format with a completion signal. Prebid holds the ad until the
     * reward is earned — a video to its end, a playable until it says so — and only then does
     * onUserEarnedReward fire. A rewarded slot may answer with video or with a playable (HTML), so
     * this asks for both.
     */
    private fun loadRewarded() {
        val unit = RewardedAdUnit(this, format.configId(settings))
        unit.setRewardedAdUnitListener(object : RewardedAdUnitListener {
            override fun onAdLoaded(u: RewardedAdUnit?) {
                report("Loaded. Presenting over the app.")
                unit.show()
            }
            override fun onAdDisplayed(u: RewardedAdUnit?) = Unit
            override fun onAdFailed(u: RewardedAdUnit?, e: AdException?) = report("Prebid: ${e?.message ?: "no ad returned"}")
            override fun onAdClicked(u: RewardedAdUnit?) = report("Clicked through.")
            override fun onAdClosed(u: RewardedAdUnit?) = report("Closed.")
            override fun onUserEarnedReward(u: RewardedAdUnit?, reward: Reward?) = grantReward(reward)
        })
        adUnits += unit
        unit.loadAd()
    }

    /**
     * Two different things, and conflating them is the usual confusion: the bid may DESCRIBE a
     * reward, and the app GRANTS it. Ours grants the same thing either way, and says whether the bid
     * had an opinion about it.
     */
    private fun grantReward(reward: Reward?) {
        val described = listOfNotNull(reward?.count?.toString(), reward?.type)
            .takeIf { it.isNotEmpty() }?.joinToString(" x ")
        report(if (described == null)
            "Reward granted: 10 Epom Coins. The bid described no reward, so the app used its own."
        else
            "Reward granted: 10 Epom Coins. The bid asked for $described.")
    }

    /**
     * Prebid's callbacks arrive on a background thread. Touching a view from there does nothing
     * visible, so the screen would look inert while the bids were in fact arriving.
     */
    private fun report(line: String) = runOnUiThread {
        log.append(line).append('\n')
        findViewById<TextView>(R.id.status).text = log.toString()
        Log.i("EpomPrebidDemo", line)
    }
}
