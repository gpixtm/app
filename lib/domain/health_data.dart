import 'models.dart';
import 'walk_metrics.dart';
import 'walk_recording.dart';

/// Optional measured values, never guessed from distance or time.
class HealthSummary {
  const HealthSummary({
    required this.readAt,
    required this.sources,
    this.steps,
    this.activeCalories,
    this.averageHeartRate,
    this.maxHeartRate,
  });
  final DateTime readAt;
  final List<String> sources;
  final int? steps;
  final double? activeCalories, averageHeartRate, maxHeartRate;
}

enum HealthAvailability {
  unavailable,
  needsInstall,
  needsPermission,
  connected,
}

/// What Gpix itself measured on a finished walk, as one Health Connect
/// exercise. Values imported from a watch through Health Connect are never
/// written back, so they cannot be counted twice.
class HealthExport {
  const HealthExport({
    required this.walkId,
    required this.title,
    required this.start,
    required this.end,
    required this.metres,
    required this.hiking,
    required this.route,
    this.ascent,
    this.steps,
    this.activeCalories,
  });

  /// Climbs from this height make the exercise a hike rather than a walk.
  static const hikingAscent = 100.0;
  final String walkId, title;
  final DateTime start, end;
  final double metres;
  final double? ascent, activeCalories;
  final int? steps;
  final bool hiking;
  final List<WalkSample> route;

  static HealthExport? of(Trail walk) {
    final details = walk.walk;
    final end = details?.ended;
    if (details == null || end == null || !end.isAfter(details.started)) {
      return null;
    }
    final metrics = WalkMetrics(walk);
    final ascent = metrics.hasElevation ? metrics.ascent : null;
    return HealthExport(
      walkId: walk.id,
      title: walk.name,
      start: details.started,
      end: end,
      metres: metrics.metres,
      hiking: (ascent ?? 0) >= hikingAscent,
      ascent: ascent,
      steps: details.health?.steps == null ? details.steps : null,
      activeCalories: details.health?.activeCalories == null
          ? details.estimatedCalories
          : null,
      route: [
        for (final sample in details.samples)
          if (!sample.time.isBefore(details.started) &&
              sample.time.isBefore(end))
            sample,
      ],
    );
  }
}

abstract interface class HealthDataSource {
  Future<HealthAvailability> status();
  Future<HealthAvailability> authorize();
  Future<HealthSummary> read(DateTime start, DateTime end);

  /// Latest body weight another app (e.g. Samsung Health) wrote, in kg.
  Future<double?> latestWeight();

  /// Permission to write exercises; the route and each measure are optional.
  Future<HealthAvailability> sharingStatus();
  Future<HealthAvailability> authorizeSharing();

  /// Insert or update the walk's exercise (idempotent per walk).
  Future<void> share(HealthExport export);
  Future<void> openSettings();
  Future<void> openZepp();
}
