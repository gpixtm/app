package fr.gpix.gpix

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import java.util.Locale

class HealthPrivacyActivity : Activity() {
    override fun attachBaseContext(base: Context) {
        val language = base.getSharedPreferences("gpix_preferences", MODE_PRIVATE).getString("language", "")
        val configuration = Configuration(base.resources.configuration)
        if (language == "en" || language == "fr") configuration.setLocale(Locale.forLanguageTag(language))
        super.attachBaseContext(base.createConfigurationContext(configuration))
    }
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val text = TextView(this).apply {
            textSize = 18f
            setPadding(32, 48, 32, 48)
            this.text = getString(R.string.health_privacy)
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }
}
