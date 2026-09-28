package fr.gpix.gpix

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build

/**
 * The phone's hardware step counter: counted by a low-power coprocessor, so it
 * keeps counting screen-off. Reports the cumulative count since the phone started.
 */
class StepCounter(context: Context) : SensorEventListener {
    private val context = context.applicationContext
    private val sensors = this.context.getSystemService(SensorManager::class.java)
    private val sensor: Sensor? = sensors?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    private var listening = false
    @Volatile private var latest: Long? = null

    val available: Boolean get() = sensor != null

    fun permitted(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
        context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    fun start(): Boolean {
        val counter = sensor ?: return false
        if (!permitted()) return false
        if (!listening) {
            // Batched delivery is fine: the count is cumulative and flushed before reads.
            listening = sensors!!.registerListener(this, counter, SensorManager.SENSOR_DELAY_NORMAL, 10_000_000)
        }
        return listening
    }

    fun read(): Long? {
        if (listening) sensors?.flush(this)
        return latest
    }

    fun stop() {
        if (listening) sensors?.unregisterListener(this)
        listening = false
        latest = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        latest = event.values.firstOrNull()?.toLong()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
