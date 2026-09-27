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

abstract interface class HealthDataSource {
  Future<HealthAvailability> status();
  Future<HealthAvailability> authorize();
  Future<HealthSummary> read(DateTime start, DateTime end);
  Future<void> openSettings();
  Future<void> openZepp();
}
