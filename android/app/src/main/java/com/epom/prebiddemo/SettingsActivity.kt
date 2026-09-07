package com.epom.prebiddemo

import android.os.Bundle
import android.text.InputType
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

/** Everything a publisher would otherwise edit in source, editable on the device. */
class SettingsActivity : AppCompatActivity() {

    private lateinit var settings: Settings
    private val fields = mutableMapOf<String, EditText>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "Settings"
        settings = Settings(this)

        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 40, 48, 48)
        }

        field(form, "server_url", "Prebid Server URL", settings.serverUrl)
        field(form, "account_id", "Prebid account id", settings.accountId)
        field(form, "config_mrec", "Config id — 300x250", settings.configIdMrec)
        field(form, "config_banner", "Config id — 320x50", settings.configIdBanner)
        field(form, "config_video", "Config id — video", settings.configIdVideo)
        field(form, "config_native", "Config id — native", settings.configIdNative)
        field(form, "config_interstitial", "Config id — interstitial video", settings.configIdInterstitial)
        field(form, "config_interstitial_image", "Config id — interstitial image", settings.configIdInterstitialImage)
        field(form, "config_playable", "Config id — playable", settings.configIdPlayable)
        field(form, "config_rewarded", "Config id — rewarded", settings.configIdRewarded)
        field(form, "ad_unit", "Google ad unit — MREC", settings.adUnitMrec)
        field(form, "ad_unit_banner", "Google ad unit — 320x50", settings.adUnitBanner)

        form.addView(TextView(this).apply {
            text = "The two \"Google renders\" screens stay off the menu until an ad unit is named " +
                "above: without one they reach nothing, and an entry that can only disappoint is " +
                "worse than no entry.\n\n" +
                "Google application id: ${settings.googleApplicationId}\n\n" +
                "Fixed at build time, in AndroidManifest.xml. The Mobile Ads SDK reads it while the " +
                "process starts — before any of this app's code runs — and crashes when it is absent, " +
                "so it cannot be changed here."
            textSize = 12f
            alpha = 0.65f
            setPadding(0, 28, 0, 28)
        })

        form.addView(Button(this).apply {
            text = "Save"
            isAllCaps = false
            setOnClickListener { save() }
        })
        form.addView(Button(this).apply {
            text = "Reset to the values in the repository"
            isAllCaps = false
            setOnClickListener {
                settings.reset()
                recreate()
            }
        })

        setContentView(ScrollView(this).apply { addView(form) })
    }

    private fun field(parent: LinearLayout, key: String, label: String, value: String) {
        parent.addView(TextView(this).apply {
            text = label
            textSize = 12f
            alpha = 0.7f
            setPadding(0, 16, 0, 4)
        })
        val input = EditText(this).apply {
            setText(value)
            setSingleLine()
            inputType = InputType.TYPE_TEXT_VARIATION_URI
            textSize = 14f
        }
        fields[key] = input
        parent.addView(input)
    }

    private fun save() {
        settings.serverUrl = fields["server_url"]!!.text.toString()
        settings.accountId = fields["account_id"]!!.text.toString()
        settings.configIdMrec = fields["config_mrec"]!!.text.toString()
        settings.configIdBanner = fields["config_banner"]!!.text.toString()
        settings.configIdVideo = fields["config_video"]!!.text.toString()
        settings.configIdNative = fields["config_native"]!!.text.toString()
        settings.configIdInterstitial = fields["config_interstitial"]!!.text.toString()
        settings.configIdInterstitialImage = fields["config_interstitial_image"]!!.text.toString()
        settings.configIdPlayable = fields["config_playable"]!!.text.toString()
        settings.configIdRewarded = fields["config_rewarded"]!!.text.toString()
        settings.adUnitBanner = fields["ad_unit_banner"]!!.text.toString()
        settings.adUnitMrec = fields["ad_unit"]!!.text.toString()
        // Prebid keeps the server it was initialised with for the life of the process, so the change
        // only takes hold on a fresh start. Saying so beats leaving the user to wonder.
        Toast.makeText(this, "Saved — restart the app for it to take effect", Toast.LENGTH_LONG).show()
        finish()
    }
}
