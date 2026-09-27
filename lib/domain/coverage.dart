import 'models.dart';

/// Exact union of axis-aligned regional envelopes, including the edges between GPX points.
class Coverage {
  Coverage(Iterable<Bounds> bounds) : bounds = bounds.toList();
  final List<Bounds> bounds;
  bool contains(GeoPoint p) => bounds.any((b) => b.contains(p));
  bool covers(Trail trail) {
    if (trail.points.isEmpty) return false;
    for (final segment in trail.segments) {
      if (!segment.every(contains)) return false;
      for (var i = 1; i < segment.length; i++) {
        final intervals =
            bounds
                .map((b) => _clip(segment[i - 1], segment[i], b))
                .whereType<(double, double)>()
                .toList()
              ..sort((a, b) => a.$1.compareTo(b.$1));
        var until = 0.0;
        for (final interval in intervals) {
          if (interval.$1 > until + 1e-9) break;
          if (interval.$2 > until) until = interval.$2;
        }
        if (until < 1 - 1e-9) return false;
      }
    }
    return true;
  }

  bool intersects(Trail trail) {
    for (final s in trail.segments) {
      if (s.any(contains)) return true;
      for (var i = 1; i < s.length; i++) {
        if (bounds.any((b) => _clip(s[i - 1], s[i], b) != null)) return true;
      }
    }
    return false;
  }

  (double, double)? _clip(GeoPoint a, GeoPoint z, Bounds b) {
    var low = 0.0, high = 1.0;
    final dx = z.lon - a.lon, dy = z.lat - a.lat;
    for (final pair in [
      (-dx, a.lon - b.west),
      (dx, b.east - a.lon),
      (-dy, a.lat - b.south),
      (dy, b.north - a.lat),
    ]) {
      final p = pair.$1, q = pair.$2;
      if (p == 0) {
        if (q < 0) return null;
        continue;
      }
      final t = q / p;
      if (p < 0) {
        if (t > high) return null;
        if (t > low) low = t;
      } else {
        if (t < low) return null;
        if (t < high) high = t;
      }
    }
    return (low, high);
  }
}
