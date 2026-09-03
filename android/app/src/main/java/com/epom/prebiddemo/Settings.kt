package com.epom.prebiddemo

import android.content.Context

/**
 * Everything the demo lets you change on the device. Defaults come from strings.xml, overrides live
 * in SharedPreferences, so a fresh install behaves exactly as the repository describes.
 *
 * The Google application id is deliberately NOT here. The Mobile Ads SDK reads it from the manifest
 * while the process starts, before any of our code runs, and crashes outright when it is missing -
 * so it cannot be a runtime setting, however convenient that would be.
 */
class Settings(private val context: Context) {

    private val prefs = context.getSharedPreferences("epom-demo", Context.MODE_PRIVATE)

    var serverUrl: String
        get() = get("server_url", R.string.prebid_server_url)
        set(v) = put("server_url", v)

    var accountId: String
        get() = get("account_id", R.string.prebid_account_id)
        set(v) = put("account_id", v)

    var configIdMrec: String
        get() = get("config_mrec", R.string.config_id_mrec)
        set(v) = put("config_mrec", v)

    var configIdBanner: String
        get() = get("config_banner", R.string.config_id_banner)
        set(v) = put("config_banner", v)

    var configIdVideo: String
        get() = get("config_video", R.string.config_id_video)
        set(v) = put("config_video", v)

    var configIdNative: String
        get() = get("config_native", R.string.config_id_native)
        set(v) = put("config_native", v)

    var configIdInterstitial: String
        get() = get("config_interstitial", R.string.config_id_interstitial)
        set(v) = put("config_interstitial", v)

    var configIdInterstitialImage: String
        get() = get("config_interstitial_image", R.string.config_id_interstitial_image)
        set(v) = put("config_interstitial_image", v)

    var configIdPlayable: String
        get() = get("config_playable", R.string.config_id_playable)
        set(v) = put("config_playable", v)

    var configIdRewarded: String
        get() = get("config_rewarded", R.string.config_id_rewarded)
        set(v) = put("config_rewarded", v)

    var adUnitMrec: String
        get() = get("ad_unit", R.string.gam_ad_unit_mrec)
        set(v) = put("ad_unit", v)

    var adUnitBanner: String
        get() = get("ad_unit_banner", R.string.gam_ad_unit_banner)
        set(v) = put("ad_unit_banner", v)

    val googleApplicationId: String
        get() = context.getString(R.string.gam_application_id)

    private fun get(key: String, fallback: Int) =
        prefs.getString(key, null)?.takeIf { it.isNotBlank() } ?: context.getString(fallback)

    private fun put(key: String, value: String) =
        prefs.edit().putString(key, value.trim()).apply()

    fun reset() = prefs.edit().clear().apply()
}
