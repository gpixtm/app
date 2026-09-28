import 'dart:math' as math;

import 'models.dart';
import 'walk_metrics.dart';

/// Share of a route a walk must cover to count as a complete walk of it, the
/// same threshold as reviews. Shorter walks stay in history as partial walks
/// and are left out of records and usual speeds.
const completeCoverage = .9;

/// Distance within which a recorded point is considered to be on the route.
const onRouteTolerance = 40.0;
// A grid cell as wide as the tolerance: the 3×3 cells around a point hold
// every edge that can be near enough.
const _bucket = 20.0, _cell = onRouteTolerance, _decimation = 10.0;

/// When a walk first reached each distance along the route, in the direction
/// it was walked, in active seconds since the walk started. Distances only grow.
class WalkProgress {
  WalkProgress(List<double> distances, List<double> seconds)
    : distances = List.unmodifiable(distances),
      seconds = List.unmodifiable(seconds);
  final List<double> distances, seconds;
  double get start => distances.first;
  double get end => distances.last;

  /// Active seconds at [distance], interpolated; null outside the walked range.
  double? secondsAt(double distance) {
    if (distance < start || distance > end) return null;
    var low = 0, high = distances.length - 1;
    while (high - low > 1) {
      final middle = (low + high) >> 1;
      if (distances[middle] <= distance) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final span = distances[high] - distances[low];
    if (span <= 0) return seconds[low];
    final f = (distance - distances[low]) / span;
    return seconds[low] + (seconds[high] - seconds[low]) * f;
  }
}

/// One walk measured against the route it belongs to.
class WalkOnRoute {
  WalkOnRoute(this.walk, {this.coverage, this.reversed = false, this.progress})
    : metrics = WalkMetrics(walk);
  final Trail walk;
  final WalkMetrics metrics;

  /// Share of the route walked, null when there is no route to compare with.
  final double? coverage;
  final bool reversed;
  final WalkProgress? progress;
  bool get finished => walk.walk!.ended != null;
  bool get complete => coverage == null || coverage! >= completeCoverage;

  /// Whether the walk counts in records and usual speeds.
  bool get counted => finished && complete && metrics.averageKmh != null;
}

/// Every walk of one route, newest first.
class RouteHistory {
  RouteHistory(this.id, this.name, this.route, List<WalkOnRoute> walks)
    : walks = List.unmodifiable(walks);

  /// Route identifier, or the walk's own identifier for a walk on no route.
  final String id, name;

  /// Line the walks are measured against; null for a lone walk on no route.
  final Trail? route;
  final List<WalkOnRoute> walks;
  WalkOnRoute get latest => walks.first;
  DateTime get lastWalked => latest.walk.walk!.started;
  DateTime get firstWalked => walks.last.walk.walk!.started;
  bool get free => walks.every((w) => w.walk.walk!.sourceTrailId == null);
  double get metres => walks.fold(0, (sum, w) => sum + w.metrics.metres);
  int get activeSeconds =>
      walks.fold(0, (sum, w) => sum + w.metrics.activeSeconds);
  Iterable<WalkOnRoute> get counted => walks.where((w) => w.counted);

  WalkOnRoute? get fastest =>
      _best(counted, (w) => w.metrics.averageKmh!.toDouble());
  WalkOnRoute? get longest =>
      _best(walks.where((w) => w.finished), (w) => w.metrics.metres);
  WalkOnRoute? get highest => _best(
    walks.where((w) => w.finished && w.metrics.hasElevation),
    (w) => w.metrics.ascent,
  );

  /// Average speed of the counted walks, [except] one; the API's rule:
  /// total distance over total active time.
  double? usualKmh({WalkOnRoute? except}) {
    var metres = 0.0, seconds = 0;
    for (final w in counted) {
      if (identical(w, except)) continue;
      metres += w.metrics.metres;
      seconds += w.metrics.activeSeconds;
    }
    return seconds > 0 && metres > 0 ? metres / seconds * 3.6 : null;
  }

  static WalkOnRoute? _best(
    Iterable<WalkOnRoute> walks,
    double Function(WalkOnRoute) value,
  ) {
    WalkOnRoute? best;
    for (final w in walks) {
      if (best == null || value(w) > value(best)) best = w;
    }
    return best;
  }
}

/// Group [walks] by the route they count for (the GPX followed, or the route a
/// free walk created or stayed on), most recently walked first. [library]
/// supplies the routes still on the phone; a guided walk's kept reference line
/// stands in for a route no longer there.
/// [measures] keeps earlier measurements, so reloading the history only
/// measures walks or routes whose lines changed.
List<RouteHistory> groupWalks(
  Iterable<Trail> walks,
  Iterable<Trail> library, {
  RouteMeasures? measures,
}) {
  final routes = {
    for (final t in library)
      if (t.walk == null && t.followable) t.id: t,
  };
  final groups = <String, List<Trail>>{};
  for (final walk in walks) {
    if (walk.walk == null) continue;
    groups
        .putIfAbsent(walk.walk!.statisticsTrailId ?? walk.id, () => [])
        .add(walk);
  }
  final result = <RouteHistory>[];
  for (final MapEntry(key: id, value: members) in groups.entries) {
    members.sort((a, b) => b.walk!.started.compareTo(a.walk!.started));
    final onRoute = members.first.walk!.statisticsTrailId != null;
    final reference = members
        .map((w) => w.walk!.reference)
        .where((r) => r != null && r.segments.any((s) => s.length > 1))
        .firstOrNull;
    final route =
        routes[id] ??
        (reference == null
            ? null
            : Trail(
                id: id,
                name: reference.name,
                segments: reference.segments,
                pois: const [],
              )) ??
        // The route was deleted from the phone: its longest walk draws it.
        (onRoute && members.length > 1
            ? members.reduce(
                (a, b) => WalkMetrics(b).metres > WalkMetrics(a).metres ? b : a,
              )
            : null);
    final name = routes[id]?.name ?? reference?.name ?? members.first.name;
    RouteIndex? index;
    result.add(
      RouteHistory(id, name, route, [
        for (final walk in members)
          route == null
              ? WalkOnRoute(walk)
              : measures?._find(route, walk) ??
                    (measures ?? RouteMeasures())._keep(
                      route,
                      (index ??= RouteIndex(route)).measure(walk),
                    ),
      ]),
    );
  }
  result.sort((a, b) => b.lastWalked.compareTo(a.lastWalked));
  return result;
}

/// Measurements of walks on routes, keyed by what they depend on: the route's
/// line and the walk's recorded points. A renamed walk or newly imported watch
/// data reuses them with the walk's current details.
class RouteMeasures {
  final _known = <String, WalkOnRoute>{};

  static String _signature(Trail route, Trail walk) {
    final points = route.segments.fold(0, (n, s) => n + s.length);
    final first = route.points.firstOrNull,
        last = route.segments.lastOrNull?.lastOrNull;
    final details = walk.walk!;
    return [
      route.id,
      points,
      first?.lat,
      first?.lon,
      last?.lat,
      last?.lon,
      walk.id,
      details.samples.length,
      details.samples.lastOrNull?.time,
      walk.segments.fold(0, (n, s) => n + s.length),
      details.seconds,
    ].join('|');
  }

  WalkOnRoute? _find(Trail route, Trail walk) {
    final known = _known[_signature(route, walk)];
    return known == null
        ? null
        : WalkOnRoute(
            walk,
            coverage: known.coverage,
            reversed: known.reversed,
            progress: known.progress,
          );
  }

  WalkOnRoute _keep(Trail route, WalkOnRoute measured) {
    // Bounded: a very long history simply measures again.
    if (_known.length > 2000) _known.clear();
    _known[_signature(route, measured.walk)] = measured;
    return measured;
  }
}

/// Seconds walk [b] trails walk [a] at each distance of their common stretch:
/// positive when [a] is ahead. Both clocks start where the stretch starts.
/// Empty when they were walked in opposite directions or barely overlap.
List<(double, double)> progressGap(
  WalkOnRoute a,
  WalkOnRoute b, {
  int steps = 120,
}) {
  final pa = a.progress, pb = b.progress;
  if (pa == null || pb == null || a.reversed != b.reversed) return const [];
  final start = math.max(pa.start, pb.start), end = math.min(pa.end, pb.end);
  if (end - start < 100) return const [];
  final a0 = pa.secondsAt(start)!, b0 = pb.secondsAt(start)!;
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final d = start + (end - start) * i / steps;
        return (d, (pb.secondsAt(d)! - b0) - (pa.secondsAt(d)! - a0));
      }(),
  ];
}

class _Edge {
  const _Edge(this.ax, this.ay, this.bx, this.by, this.start, this.length);
  final double ax, ay, bx, by, start, length;
}

/// A route's edges in a metric grid, so each recorded point only looks at the
/// edges near it. Distances follow the shared axis: segment gaps add nothing.
class RouteIndex {
  RouteIndex(this.route) {
    final first = route.points.firstOrNull;
    _latitude = first?.lat ?? 0;
    _scale = math.cos(_latitude * math.pi / 180);
    for (final segment in route.segments) {
      for (var i = 1; i < segment.length; i++) {
        final length = distance(segment[i - 1], segment[i]);
        if (length > 0) {
          final (ax, ay) = _xy(segment[i - 1]);
          final (bx, by) = _xy(segment[i]);
          final edge = _Edge(ax, ay, bx, by, total, length);
          for (
            var cx = (math.min(ax, bx) / _cell).floor();
            cx <= (math.max(ax, bx) / _cell).floor();
            cx++
          ) {
            for (
              var cy = (math.min(ay, by) / _cell).floor();
              cy <= (math.max(ay, by) / _cell).floor();
              cy++
            ) {
              _grid.putIfAbsent(_key(cx, cy), () => []).add(edge);
            }
          }
        }
        total += length;
      }
    }
  }
  final Trail route;
  double total = 0;
  late final double _latitude, _scale;
  final Map<int, List<_Edge>> _grid = {};
  static int _key(int x, int y) => x * 16777216 + y;

  (double, double) _xy(GeoPoint p) =>
      (p.lon * _scale * 111320, (p.lat - _latitude) * 110574);

  /// Distances along the route within [onRouteTolerance] of [p], nearest
  /// first, distant passages at the same place kept apart.
  List<double> candidates(GeoPoint p) {
    final (x, y) = _xy(p);
    final cx = (x / _cell).floor(), cy = (y / _cell).floor();
    final found = <(double, double)>[];
    const limit = onRouteTolerance * onRouteTolerance;
    // An edge crossing several cells is found more than once; its duplicates
    // share one distance along the route and merge below.
    for (var i = cx - 1; i <= cx + 1; i++) {
      for (var j = cy - 1; j <= cy + 1; j++) {
        for (final e in _grid[_key(i, j)] ?? const <_Edge>[]) {
          final dx = e.bx - e.ax, dy = e.by - e.ay;
          final d2 = dx * dx + dy * dy;
          final f = d2 == 0
              ? 0.0
              : (((x - e.ax) * dx + (y - e.ay) * dy) / d2).clamp(0.0, 1.0);
          final gx = x - e.ax - dx * f, gy = y - e.ay - dy * f;
          final gap = gx * gx + gy * gy;
          if (gap <= limit) found.add((gap, e.start + e.length * f));
        }
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    final result = <double>[];
    for (final (_, along) in found) {
      if (result.every((a) => (a - along).abs() > 75)) result.add(along);
    }
    return result;
  }

  /// Coverage, direction and progress of [walk] on this route. A point keeps
  /// to the passage closest to where the walker was, so loops and
  /// out-and-back routes are followed rather than jumping between passages.
  WalkOnRoute measure(Trail walk) {
    final details = walk.walk!;
    final points = _timedPoints(walk);
    final buckets = List.filled(math.max(1, (total / _bucket).ceil()), false);
    double? previous;
    var walked = 0.0, sinceOnRoute = 0.0, direction = 0.0;
    GeoPoint? last;
    final alongs = <double?>[];
    final linked = <bool>[];
    for (final (point, _) in points) {
      if (last != null) {
        final step = distance(last, point);
        walked += step;
        sinceOnRoute += step;
      }
      last = point;
      final options = candidates(point);
      if (options.isEmpty) {
        alongs.add(null);
        linked.add(false);
        continue;
      }
      final budget = sinceOnRoute * 1.5 + 80;
      final near = previous == null
          ? const <double>[]
          : options.where((a) => (a - previous!).abs() <= budget).toList();
      final along = near.isEmpty
          ? options.first
          : near.reduce(
              (a, b) => (a - previous!).abs() <= (b - previous).abs() ? a : b,
            );
      final link = near.isNotEmpty;
      if (link) {
        direction += along - previous!;
        final from = (math.min(along, previous) / _bucket).floor();
        final to = (math.max(along, previous) / _bucket).floor();
        for (var i = from; i <= to && i < buckets.length; i++) {
          buckets[i] = true;
        }
      } else {
        buckets[math.min(buckets.length - 1, (along / _bucket).floor())] = true;
      }
      alongs.add(along);
      linked.add(link);
      previous = along;
      sinceOnRoute = 0;
    }
    if (walked == 0 && points.length < 2) {
      return WalkOnRoute(walk, coverage: 0);
    }
    final reversed = direction < 0;
    WalkProgress? progress;
    if (details.samples.isNotEmpty) {
      final distances = <double>[], seconds = <double>[];
      double? lastDistance, lastSeconds;
      for (var i = 0; i < points.length; i++) {
        final along = alongs[i];
        if (along == null) continue;
        final d = reversed ? total - along : along, t = points[i].$2!;
        if (linked[i] && lastDistance != null) {
          if (distances.isEmpty) {
            distances.add(lastDistance);
            seconds.add(lastSeconds!);
          }
          if (d > distances.last) {
            distances.add(d);
            seconds.add(t);
          }
        }
        lastDistance = d;
        lastSeconds = t;
      }
      if (distances.length > 1) progress = WalkProgress(distances, seconds);
    }
    return WalkOnRoute(
      walk,
      coverage: buckets.where((b) => b).length / buckets.length,
      reversed: reversed,
      progress: progress,
    );
  }

  /// Recorded points about ten metres apart, with active seconds since the
  /// start when the walk kept its samples. A pause adds no time; a GPS gap
  /// adds the time its distance takes at the walk's average speed.
  static List<(GeoPoint, double?)> _timedPoints(Trail walk) {
    final details = walk.walk!;
    final result = <(GeoPoint, double?)>[];
    GeoPoint? kept;
    void keep(GeoPoint p, double? t, {bool force = false}) {
      if (force || kept == null || distance(kept!, p) >= _decimation) {
        result.add((p, t));
        kept = p;
      }
    }

    final samples = details.samples;
    if (samples.isEmpty) {
      for (final segment in walk.segments) {
        for (var i = 0; i < segment.length; i++) {
          keep(segment[i], null, force: i == segment.length - 1);
        }
      }
      return result;
    }
    final metres = WalkMetrics(walk).metres;
    final speed = details.seconds > 0 && metres > 0
        ? metres / details.seconds
        : 1.3;
    var active = 0.0;
    for (var i = 0; i < samples.length; i++) {
      if (i > 0) {
        final a = samples[i - 1], b = samples[i];
        final seconds = math.max(
          0.0,
          b.time.difference(a.time).inMilliseconds / 1000,
        );
        active += a.segment == b.segment
            ? seconds
            : math.min(seconds, distance(a.point, b.point) / speed);
      }
      final lastOfSegment =
          i == samples.length - 1 ||
          samples[i + 1].segment != samples[i].segment;
      keep(samples[i].point, active, force: lastOfSegment);
    }
    return result;
  }
}
