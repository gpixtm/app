import 'models.dart';
import 'trail_geometry.dart';

/// Running totals of the finished walks that followed one GPX. The API keeps
/// them incrementally; the phone caches them for offline comparisons.
class TrailStatistics {
  const TrailStatistics(this.trailId, this.walks, this.metres, this.seconds);
  final String trailId;
  final int walks;
  final double metres;
  final int seconds;
  double? get averageKmh =>
      seconds > 0 && metres > 0 ? metres / seconds * 3.6 : null;

  TrailStatistics add(WalkContribution walk) => TrailStatistics(
    trailId,
    walks + 1,
    metres + walk.metres,
    seconds + walk.seconds,
  );
}

/// What one finished walk adds to its GPX statistics. Same rule as the API:
/// recorded distance (segment gaps add nothing), active time, minimum size.
class WalkContribution {
  const WalkContribution(this.trailId, this.metres, this.seconds);
  static const minimumMetres = 500.0, minimumSeconds = 60;
  final String trailId;
  final double metres;
  final int seconds;

  static WalkContribution? of(Trail walk) {
    final details = walk.walk;
    final source = details?.statisticsTrailId;
    if (details == null || details.ended == null || source == null) return null;
    final metres = TrailGeometry(walk).total;
    if (metres < minimumMetres || details.seconds < minimumSeconds) return null;
    return WalkContribution(source, metres, details.seconds);
  }
}

abstract interface class TrailStatisticsStore {
  Future<TrailStatistics?> find(String trailId);

  /// Replace the cache with the server totals, which include every synced walk.
  Future<void> replaceAll(List<TrailStatistics> statistics);

  /// Count a walk finished on this phone until the next server refresh.
  Future<void> addWalk(Trail walk);
}

abstract interface class StatisticsTransport {
  Future<List<TrailStatistics>> fetch();
}
