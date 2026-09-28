package fr.gpix.gpix

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/**
 * Turn-by-turn delivery outside the Flutter UI: a notification with a direction
 * pictogram and the device's own offline text-to-speech engine (no paid service).
 * Runs screen-off while the location foreground service keeps the process alive.
 */
class TurnGuidance(context: Context) : TextToSpeech.OnInitListener {
    private val context = context.applicationContext
    private val notifications = this.context.getSystemService(NotificationManager::class.java)
    private val audio = this.context.getSystemService(AudioManager::class.java)
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        .setAudioAttributes(attributes)
        .build()
    private var engine: TextToSpeech? = null
    private var ready = false
    private var pending: Triple<String, String, Boolean>? = null

    fun canNotify(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun announce(kind: String, title: String, body: String, speech: String, language: String, speak: Boolean, notify: Boolean) {
        val recap = kind == RECAP
        if (notify) post(kind, title, body, language, recap)
        // A direction change interrupts anything being said; a summary waits its turn.
        if (speak && speech.isNotBlank()) say(speech, language, interrupt = !recap)
    }

    fun clear() {
        notifications.cancel(NOTIFICATION_ID)
        notifications.cancel(RECAP_NOTIFICATION_ID)
    }

    fun close() {
        clear()
        engine?.stop()
        engine?.shutdown()
        engine = null
        ready = false
        pending = null
        audio.abandonAudioFocusRequest(focus)
    }

    private fun say(text: String, language: String, interrupt: Boolean) {
        if (engine == null) {
            ready = false
            engine = TextToSpeech(context, this)
        }
        if (ready) speakNow(text, language, interrupt) else pending = Triple(text, language, interrupt)
    }

    override fun onInit(status: Int) {
        val tts = engine ?: return
        if (status != TextToSpeech.SUCCESS) {
            // Retry initialization on the next instruction (e.g. engine being updated).
            tts.shutdown()
            engine = null
            pending = null
            return
        }
        ready = true
        tts.setAudioAttributes(attributes)
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) { audio.abandonAudioFocusRequest(focus) }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) { audio.abandonAudioFocusRequest(focus) }
        })
        pending?.let { speakNow(it.first, it.second, it.third) }
        pending = null
    }

    private fun speakNow(text: String, language: String, interrupt: Boolean) {
        val tts = engine ?: return
        val locale = Locale.forLanguageTag(language.ifBlank { "en" })
        if (tts.isLanguageAvailable(locale) >= TextToSpeech.LANG_AVAILABLE) tts.language = locale
        audio.requestAudioFocus(focus)
        tts.speak(text, if (interrupt) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD, null, UTTERANCE_ID)
    }

    private fun localized(language: String): Context {
        if (language != "en" && language != "fr") return context
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(language))
        return context.createConfigurationContext(configuration)
    }

    private fun post(kind: String, title: String, body: String, language: String, recap: Boolean) {
        if (!canNotify()) return
        val resources = localized(language)
        val channel = if (recap) RECAP_CHANNEL_ID else CHANNEL_ID
        // Recreating an existing channel only refreshes its localized name and description.
        notifications.createNotificationChannel(
            if (recap) {
                NotificationChannel(RECAP_CHANNEL_ID, resources.getString(R.string.recap_channel), NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = resources.getString(R.string.recap_channel_description)
                    setSound(null, null)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 120)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            } else {
                NotificationChannel(CHANNEL_ID, resources.getString(R.string.guidance_channel), NotificationManager.IMPORTANCE_HIGH).apply {
                    description = resources.getString(R.string.guidance_channel_description)
                    setSound(null, null)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 250, 150, 250)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            }
        )
        val icon = ICONS[kind] ?: R.drawable.ic_guidance_arrive
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        val builder = Notification.Builder(context, channel)
            .setSmallIcon(icon)
            .setLargeIcon(Icon.createWithBitmap(picture(icon)))
            .setContentTitle(title)
            .setCategory(if (recap) Notification.CATEGORY_STATUS else Notification.CATEGORY_NAVIGATION)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(FOREST)
            .setShowWhen(true)
            .setAutoCancel(true)
            .setTimeoutAfter(15 * 60 * 1000L)
        if (body.isNotBlank()) {
            // Multi-line summaries show the first line collapsed and every line expanded.
            builder.setContentText(body.lineSequence().first())
            if (body.contains('\n')) builder.setStyle(Notification.BigTextStyle().bigText(body))
        }
        if (launch != null) {
            builder.setContentIntent(
                PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            )
        }
        notifications.notify(if (recap) RECAP_NOTIFICATION_ID else NOTIFICATION_ID, builder.build())
    }

    private fun picture(icon: Int): Bitmap {
        val size = (64 * context.resources.displayMetrics.density).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val drawable = context.getDrawable(icon)!!.mutate()
        drawable.setTint(FOREST)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        return bitmap
    }

    companion object {
        private const val CHANNEL_ID = "gpix_guidance"
        private const val NOTIFICATION_ID = 4801
        private const val RECAP = "recap"
        private const val RECAP_CHANNEL_ID = "gpix_recap"
        private const val RECAP_NOTIFICATION_ID = 4802
        private const val UTTERANCE_ID = "gpix-guidance"
        private const val FOREST = 0xFF174B38.toInt()
        private val ICONS = mapOf(
            "slightLeft" to R.drawable.ic_guidance_slight_left,
            "left" to R.drawable.ic_guidance_left,
            "sharpLeft" to R.drawable.ic_guidance_sharp_left,
            "uTurnLeft" to R.drawable.ic_guidance_u_turn_left,
            "slightRight" to R.drawable.ic_guidance_slight_right,
            "right" to R.drawable.ic_guidance_right,
            "sharpRight" to R.drawable.ic_guidance_sharp_right,
            "uTurnRight" to R.drawable.ic_guidance_u_turn_right,
            "arrive" to R.drawable.ic_guidance_arrive,
            "reachTrail" to R.drawable.ic_guidance_arrive,
            "offTrail" to R.drawable.ic_guidance_off_trail,
            RECAP to R.drawable.ic_guidance_recap,
        )
    }
}
