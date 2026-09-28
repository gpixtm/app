/// Information a kilometre summary can contain, in reading order.
enum RecapItem {
  distance,
  duration,
  steps,
  calories,
  currentSpeed,
  averageSpeed,
  comparison,
  remaining,
  arrival,
  ascent,
  clock;

  static const spokenByDefault = {
    distance,
    duration,
    steps,
    calories,
    averageSpeed,
    comparison,
    remaining,
  };

  static Set<RecapItem> parse(String? saved) => saved == null
      ? spokenByDefault
      : {
          for (final name in saved.split(','))
            ...values.where((item) => item.name == name),
        };

  static String format(Set<RecapItem> items) =>
      values.where(items.contains).map((item) => item.name).join(',');
}

/// Progress summary announced at each walked kilometre. Absent values are
/// omitted (no GPX followed, no previous walk, no elevation) rather than zero.
class WalkRecap {
  const WalkRecap({
    required this.kilometre,
    required this.metres,
    required this.activeSeconds,
    required this.clock,
    this.splitKmh,
    this.averageKmh,
    this.remainingMetres,
    this.arrival,
    this.usualKmh,
    this.previousWalks,
    this.ascent,
    this.steps,
    this.calories,
  });
  final int? steps;

  /// Active kcal estimated from the track and the walker's weight.
  final double? calories;
  final int kilometre;
  final double metres;
  final int activeSeconds;
  final DateTime clock;
  final double? splitKmh, averageKmh, remainingMetres, usualKmh, ascent;
  final DateTime? arrival;
  final int? previousWalks;

  /// Current average minus the usual average of this GPX, in km/h.
  double? get difference =>
      averageKmh == null || usualKmh == null ? null : averageKmh! - usualKmh!;

  Set<RecapItem> get available => {
    RecapItem.distance,
    RecapItem.duration,
    if (steps != null) RecapItem.steps,
    if (calories != null) RecapItem.calories,
    if (splitKmh != null) RecapItem.currentSpeed,
    if (averageKmh != null) RecapItem.averageSpeed,
    if (difference != null) RecapItem.comparison,
    if (remainingMetres != null) RecapItem.remaining,
    if (arrival != null) RecapItem.arrival,
    if (ascent != null) RecapItem.ascent,
    RecapItem.clock,
  };
}
