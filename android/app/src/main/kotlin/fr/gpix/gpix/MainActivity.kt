package fr.gpix.gpix

import android.content.Intent
import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val permissions = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class)
    )
    private var awaiting: MethodChannel.Result? = null
    private val permissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        awaiting?.success(if (granted.containsAll(permissions)) "connected" else "needsPermission")
        awaiting = null
    }
    private var awaitingSharing: MethodChannel.Result? = null
    private val sharingLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        awaitingSharing?.success(if (HealthShare.canShare(granted)) "connected" else "needsPermission")
        awaitingSharing = null
    }
    private val guidance by lazy { TurnGuidance(this) }
    private var awaitingNotifications: MethodChannel.Result? = null
    private val notificationLauncher = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        awaitingNotifications?.success(granted)
        awaitingNotifications = null
    }
    private val steps by lazy { StepCounter(this) }
    private var awaitingSteps: MethodChannel.Result? = null
    private val stepLauncher = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        awaitingSteps?.success(granted && steps.start())
        awaitingSteps = null
    }
    private fun available(): String = when (HealthConnectClient.getSdkStatus(this)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "needsInstall"
        else -> "unavailable"
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "gpix/locale").setMethodCallHandler { call, result ->
            if (call.method != "select") { result.notImplemented(); return@setMethodCallHandler }
            val language = call.argument<String>("language") ?: ""
            if (language !in setOf("", "en", "fr")) { result.error("locale", "Unsupported language", null); return@setMethodCallHandler }
            if (getSharedPreferences("gpix_preferences", MODE_PRIVATE).edit().putString("language", language).commit()) {
                result.success(null)
            } else { result.error("locale", "Cannot save native language preference", null) }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "gpix/navigation").setMethodCallHandler { call, result ->
            if (call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
            try {
                val uri = Uri.parse(call.argument<String>("url") ?: "")
                require(uri.scheme == "https" && uri.host in setOf("www.google.com", "www.openstreetmap.org"))
                startActivity(Intent(Intent.ACTION_VIEW, uri))
                result.success(null)
            } catch (e: Exception) { result.error("navigation", "Cannot open navigation", null) }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "gpix/steps").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> when {
                        !steps.available -> result.success(false)
                        steps.permitted() -> result.success(steps.start())
                        awaitingSteps != null -> result.error("busy", "Request already open", null)
                        else -> {
                            awaitingSteps = result
                            stepLauncher.launch(android.Manifest.permission.ACTIVITY_RECOGNITION)
                        }
                    }
                    "read" -> result.success(steps.read())
                    "stop" -> { steps.stop(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("steps", "Step counter unavailable", null) }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "gpix/guidance").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "prepare" -> when {
                        guidance.canNotify() -> result.success(true)
                        awaitingNotifications != null -> result.error("busy", "Request already open", null)
                        else -> {
                            awaitingNotifications = result
                            notificationLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }
                    "announce" -> {
                        guidance.announce(
                            call.argument<String>("kind") ?: "",
                            call.argument<String>("title") ?: "",
                            call.argument<String>("body") ?: "",
                            call.argument<String>("speech") ?: "",
                            call.argument<String>("language") ?: "",
                            call.argument<Boolean>("speak") == true,
                            call.argument<Boolean>("notify") == true
                        )
                        result.success(null)
                    }
                    "clear" -> { guidance.clear(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("guidance", "Guidance unavailable", null) }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "gpix/health").setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    when (call.method) {
                        "status" -> {
                            val status = available()
                            if (status != "available") result.success(status)
                            else result.success(if (HealthConnectClient.getOrCreate(this@MainActivity).permissionController.getGrantedPermissions().containsAll(permissions)) "connected" else "needsPermission")
                        }
                        "authorize" -> {
                            val status = available()
                            if (status != "available") result.success(status)
                            else if (awaiting != null) result.error("busy", "Request already open", null)
                            else { awaiting = result; permissionLauncher.launch(permissions + HealthShare.weightPermission) }
                        }
                        "settings" -> {
                            val intent = if (available() == "available") Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
                              else Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.google.android.apps.healthdata"))
                            startActivity(intent); result.success(null)
                        }
                        "zepp" -> {
                            val intent = packageManager.getLaunchIntentForPackage("com.huami.watch.hmwatchmanager")
                              ?: Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.huami.watch.hmwatchmanager"))
                            startActivity(intent); result.success(null)
                        }
                        "weight" -> {
                            if (available() != "available") result.success(null)
                            else result.success(HealthShare.latestWeight(HealthConnectClient.getOrCreate(this@MainActivity)))
                        }
                        "sharingStatus" -> {
                            val status = available()
                            if (status != "available") result.success(status)
                            else result.success(if (HealthShare.canShare(HealthConnectClient.getOrCreate(this@MainActivity).permissionController.getGrantedPermissions())) "connected" else "needsPermission")
                        }
                        "authorizeSharing" -> {
                            val status = available()
                            if (status != "available") result.success(status)
                            else if (awaitingSharing != null) result.error("busy", "Request already open", null)
                            else { awaitingSharing = result; sharingLauncher.launch(HealthShare.writePermissions) }
                        }
                        "share" -> {
                            @Suppress("UNCHECKED_CAST")
                            HealthShare.share(HealthConnectClient.getOrCreate(this@MainActivity), call.arguments as Map<String, Any?>)
                            result.success(null)
                        }
                        "read" -> {
                            val client = HealthConnectClient.getOrCreate(this@MainActivity)
                            val granted = client.permissionController.getGrantedPermissions()
                            val metrics = buildSet {
                                if (HealthPermission.getReadPermission(HeartRateRecord::class) in granted) { add(HeartRateRecord.BPM_AVG); add(HeartRateRecord.BPM_MAX) }
                                if (HealthPermission.getReadPermission(StepsRecord::class) in granted) add(StepsRecord.COUNT_TOTAL)
                                if (HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class) in granted) add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                            }
                            if (metrics.isEmpty()) { result.error("permission", "Grant health data access in watch settings", null); return@launch }
                            val start = Instant.parse(call.argument<String>("start")!!)
                            val end = Instant.parse(call.argument<String>("end")!!)
                            require(end.isAfter(start))
                            val values = client.aggregate(AggregateRequest(metrics, TimeRangeFilter.between(start, end)))
                            result.success(mapOf(
                                "steps" to values[StepsRecord.COUNT_TOTAL],
                                "activeCalories" to values[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories,
                                "averageHeartRate" to values[HeartRateRecord.BPM_AVG],
                                "maxHeartRate" to values[HeartRateRecord.BPM_MAX],
                                "sources" to values.dataOrigins.map { it.packageName }
                            ))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    if (awaiting === result) awaiting = null
                    if (awaitingSharing === result) awaitingSharing = null
                    result.error("health", e.message ?: "Health Connect indisponible", null)
                }
            }
        }
    }
    override fun onResume() {
        super.onResume()
        // The visible map shows the current instruction; drop the stale notification.
        guidance.clear()
    }
    override fun onDestroy() {
        awaiting?.error("closed", "Request interrupted", null); awaiting = null
        awaitingSharing?.error("closed", "Request interrupted", null); awaitingSharing = null
        awaitingNotifications?.success(false); awaitingNotifications = null
        guidance.close()
        awaitingSteps?.success(false); awaitingSteps = null
        steps.stop()
        scope.cancel()
        super.onDestroy()
    }
}
