package fr.gpix.gpix

import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** Weight reading and walk export through Health Connect. */
object HealthShare {
    val weightPermission = HealthPermission.getReadPermission(WeightRecord::class)
    private val sessionPermission = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    val writePermissions = setOf(
        sessionPermission,
        HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE,
        HealthPermission.getWritePermission(DistanceRecord::class),
        HealthPermission.getWritePermission(ElevationGainedRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
    )

    /** Sharing needs at least the exercise itself; each measure is optional. */
    fun canShare(granted: Set<String>) = sessionPermission in granted

    /** Latest weight written by any app within the last two years, in kg. */
    suspend fun latestWeight(client: HealthConnectClient): Double? {
        if (weightPermission !in client.permissionController.getGrantedPermissions()) return null
        val now = Instant.now()
        val records = client.readRecords(
            ReadRecordsRequest(
                WeightRecord::class,
                TimeRangeFilter.between(now.minus(730, ChronoUnit.DAYS), now),
                ascendingOrder = false,
                pageSize = 1,
            )
        ).records
        return records.firstOrNull()?.weight?.inKilograms
    }

    /**
     * One exercise session with its route and the measures Gpix produced.
     * Stable client identifiers make a repeated export an update, not a copy.
     */
    suspend fun share(client: HealthConnectClient, walk: Map<String, Any?>) {
        val granted = client.permissionController.getGrantedPermissions()
        require(canShare(granted)) { "Exercise write permission missing" }
        val id = walk["id"] as String
        val start = Instant.parse(walk["start"] as String)
        val end = Instant.parse(walk["end"] as String)
        require(end.isAfter(start))
        val zone = ZoneId.systemDefault().rules
        val startOffset = zone.getOffset(start)
        val endOffset = zone.getOffset(end)
        val device = Device(type = Device.TYPE_PHONE, manufacturer = Build.MANUFACTURER, model = Build.MODEL)
        val version = System.currentTimeMillis()
        fun metadata(kind: String) = Metadata.activelyRecorded(device, "gpix-$id-$kind", version)
        fun allowed(type: kotlin.reflect.KClass<out Record>) = HealthPermission.getWritePermission(type) in granted

        @Suppress("UNCHECKED_CAST")
        val points = (walk["route"] as? List<List<Any?>>).orEmpty().mapNotNull { p ->
            val time = Instant.parse(p[0] as String)
            if (time.isBefore(start) || !time.isBefore(end)) return@mapNotNull null
            ExerciseRoute.Location(
                time = time,
                latitude = (p[1] as Number).toDouble(),
                longitude = (p[2] as Number).toDouble(),
                horizontalAccuracy = (p[3] as? Number)?.let { Length.meters(it.toDouble()) },
                altitude = (p[4] as? Number)?.let { Length.meters(it.toDouble()) },
            )
        }.distinctBy { it.time }.sortedBy { it.time }
        val route = if (HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE in granted && points.isNotEmpty()) ExerciseRoute(points) else null

        val records = mutableListOf<Record>(
            ExerciseSessionRecord(
                startTime = start,
                startZoneOffset = startOffset,
                endTime = end,
                endZoneOffset = endOffset,
                metadata = metadata("session"),
                exerciseType = if (walk["hiking"] == true) ExerciseSessionRecord.EXERCISE_TYPE_HIKING else ExerciseSessionRecord.EXERCISE_TYPE_WALKING,
                title = walk["title"] as? String,
                exerciseRoute = route,
            )
        )
        (walk["metres"] as? Number)?.toDouble()?.takeIf { it > 0 && allowed(DistanceRecord::class) }?.let {
            records += DistanceRecord(start, startOffset, end, endOffset, Length.meters(it), metadata("distance"))
        }
        (walk["ascent"] as? Number)?.toDouble()?.takeIf { it > 0 && allowed(ElevationGainedRecord::class) }?.let {
            records += ElevationGainedRecord(start, startOffset, end, endOffset, Length.meters(it), metadata("ascent"))
        }
        (walk["steps"] as? Number)?.toLong()?.takeIf { it > 0 && allowed(StepsRecord::class) }?.let {
            records += StepsRecord(start, startOffset, end, endOffset, it, metadata("steps"))
        }
        (walk["activeCalories"] as? Number)?.toDouble()?.takeIf { it > 0 && allowed(ActiveCaloriesBurnedRecord::class) }?.let {
            records += ActiveCaloriesBurnedRecord(start, startOffset, end, endOffset, Energy.kilocalories(it), metadata("calories"))
        }
        client.insertRecords(records)
    }
}
