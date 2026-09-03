package com.epom.prebiddemo

import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/** The format picker. Every screen behind it asks the same Prebid Server for the same account. */
class MenuActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_menu)
        val menu = findViewById<LinearLayout>(R.id.menu)

        menu.addView(TextView(this).apply {
            text = getString(R.string.menu_intro)
            textSize = 13f
            setPadding(0, 0, 0, 24)
        })

        menu.addView(Button(this).apply {
            text = "Settings"
            isAllCaps = false
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            setOnClickListener { startActivity(Intent(this@MenuActivity, SettingsActivity::class.java)) }
        })
        menu.addView(TextView(this).apply {
            text = "Prebid Server, account and slot ids — editable on the device"
            textSize = 12f
            alpha = 0.6f
            setPadding(8, 0, 0, 28)
        })

        Format.entries.forEach { format ->
            menu.addView(Button(this).apply {
                text = format.title
                isAllCaps = false
                // The Google-rendered screens are coloured apart: they behave and fail differently,
                // needing a line item before they show anything.
                if (format.rendersThroughGoogle) setBackgroundColor(0xFF0D9488.toInt())
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                setOnClickListener {
                    startActivity(Intent(this@MenuActivity, AdActivity::class.java)
                        .putExtra(AdActivity.EXTRA_FORMAT, format.name))
                }
            })
            menu.addView(TextView(this).apply {
                text = format.subtitle
                textSize = 12f
                alpha = 0.6f
                setPadding(8, 0, 0, 20)
            })
        }
    }
}
