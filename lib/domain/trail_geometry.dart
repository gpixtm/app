import 'dart:math' as math;

import 'models.dart';

class Projection {
  const Projection(this.along, this.offTrail, this.point);
  final double along, offTrail;
  final GeoPoint point;
}

class ProfilePoint {
  const ProfilePoint(this.distance, this.elevation, this.segment);
  final double distance;
  final double? elevation;
  final int segment;
}

class _Edge {
  const _Edge(this.a, this.b, this.start, this.length, this.segment);
  final GeoPoint a, b;
  final double start, length;
  final int segment;
}

/// One distance axis shared by tracking and elevation. Segment gaps add no distance.
class TrailGeometry {
  TrailGeometry(this.trail) {
    for (var s = 0; s < trail.segments.length; s++) {
      final segment = trail.segments[s];
      for (var i = 0; i < segment.length; i++) {
        if (i > 0) {
          final length = distance(segment[i - 1], segment[i]);
          if (length > 0) {
            _edges.add(_Edge(segment[i - 1], segment[i], total, length, s));
          }
          total += length;
        }
        profile.add(ProfilePoint(total, segment[i].elevation, s));
      }
    }
  }
  final List<_Edge> _edges = [];
  final Trail trail;
  final List<ProfilePoint> profile = [];
  double total = 0;

  /// Clip on the shared distance axis without joining separate GPX segments.
  List<List<GeoPoint>> portion(double start, double end) {
    final low = math.min(start, end).clamp(0.0, total);
    final high = math.max(start, end).clamp(0.0, total);
    var along = 0.0;
    final result = <List<GeoPoint>>[];
    for (final segment in trail.segments) {
      final points = <GeoPoint>[];
      for (var i = 1; i < segment.length; i++) {
        final a = segment[i - 1], b = segment[i];
        final length = distance(a, b);
        final next = along + length;
        if (length > 0 && next > low && along < high) {
          GeoPoint at(double value) {
            final f = ((value - along) / length).clamp(0.0, 1.0);
            return GeoPoint(
              a.lat + (b.lat - a.lat) * f,
              a.lon + (b.lon - a.lon) * f,
              a.elevation == null || b.elevation == null
                  ? null
                  : a.elevation! + (b.elevation! - a.elevation!) * f,
            );
          }

          if (points.isEmpty) points.add(at(low));
          points.add(at(high));
        }
        along = next;
      }
      if (points.length > 1) result.add(points);
    }
    return start > end
        ? result.reversed.map((s) => s.reversed.toList()).toList()
        : result;
  }

  GeoPoint? pointAt(double along) {
    for (final e in _edges) {
      if (along <= e.start + e.length) {
        final f = ((along - e.start) / e.length).clamp(0.0, 1.0);
        return GeoPoint(
          e.a.lat + (e.b.lat - e.a.lat) * f,
          e.a.lon + (e.b.lon - e.a.lon) * f,
        );
      }
    }
    return _edges.lastOrNull?.b;
  }

  /// Middle of the longest portion inside [view], on the shared distance axis.
  /// Separate GPX segments never merge into one visible portion.
  GeoPoint? visibleCentre(Bounds view) {
    double? runStart, runEnd, bestStart, bestEnd;
    int? runSegment;
    void close() {
      if (runStart != null &&
          (bestStart == null || runEnd! - runStart! > bestEnd! - bestStart!)) {
        bestStart = runStart;
        bestEnd = runEnd;
      }
      runStart = null;
    }

    for (final e in _edges) {
      final clip = _clip(e, view);
      if (clip == null) {
        close();
        continue;
      }
      final from = e.start + e.length * clip.$1;
      final to = e.start + e.length * clip.$2;
      if (runStart != null &&
          runSegment == e.segment &&
          (from - runEnd!).abs() < 1e-6) {
        runEnd = to;
      } else {
        close();
        runStart = from;
        runEnd = to;
        runSegment = e.segment;
      }
    }
    close();
    return bestStart == null ? null : pointAt((bestStart! + bestEnd!) / 2);
  }

  /// Liang–Barsky clipping of an edge in longitude/latitude space.
  static (double, double)? _clip(_Edge e, Bounds b) {
    var t0 = 0.0, t1 = 1.0;
    final dx = e.b.lon - e.a.lon, dy = e.b.lat - e.a.lat;
    for (final (p, q) in [
      (-dx, e.a.lon - b.west),
      (dx, b.east - e.a.lon),
      (-dy, e.a.lat - b.south),
      (dy, b.north - e.a.lat),
    ]) {
      if (p == 0) {
        if (q < 0) return null;
        continue;
      }
      final r = q / p;
      if (p < 0) {
        if (r > t1) return null;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) return null;
        if (r < t1) t1 = r;
      }
    }
    return (t0, t1);
  }

  Projection? project(
    GeoPoint p, {
    double? previous,
    double maxTravel = double.infinity,
  }) {
    Projection? nearest, continuous;
    for (final e in _edges) {
      final scale = math.cos(p.lat * math.pi / 180);
      final dx = (e.b.lon - e.a.lon) * scale, dy = e.b.lat - e.a.lat;
      final denominator = dx * dx + dy * dy;
      final f = denominator == 0
          ? 0.0
          : (((p.lon - e.a.lon) * scale * dx + (p.lat - e.a.lat) * dy) /
                    denominator)
                .clamp(0.0, 1.0);
      final q = GeoPoint(e.a.lat + dy * f, e.a.lon + (e.b.lon - e.a.lon) * f);
      final candidate = Projection(e.start + e.length * f, distance(p, q), q);
      if (nearest == null || candidate.offTrail < nearest.offTrail) {
        nearest = candidate;
      }
      if (previous != null &&
          (candidate.along - previous).abs() <= maxTravel &&
          (continuous == null || candidate.offTrail < continuous.offTrail)) {
        continuous = candidate;
      }
    }
    // Keep the branch at crossings; reacquire only when it is clearly implausible.
    if (continuous != null &&
        nearest != null &&
        continuous.offTrail <= nearest.offTrail + 30) {
      return continuous;
    }
    return nearest;
  }

  /// Distinguish distant visits to the same location (loops or out-and-back).
  List<Projection> pickCandidates(GeoPoint p, double tolerance) {
    final candidates = <Projection>[];
    for (final e in _edges) {
      final scale = math.cos(p.lat * math.pi / 180);
      final dx = (e.b.lon - e.a.lon) * scale, dy = e.b.lat - e.a.lat;
      final den = dx * dx + dy * dy;
      final f = den == 0
          ? 0.0
          : (((p.lon - e.a.lon) * scale * dx + (p.lat - e.a.lat) * dy) / den)
                .clamp(0.0, 1.0);
      final q = GeoPoint(e.a.lat + dy * f, e.a.lon + (e.b.lon - e.a.lon) * f);
      final gap = distance(p, q);
      if (gap <= tolerance) {
        candidates.add(Projection(e.start + e.length * f, gap, q));
      }
    }
    candidates.sort((a, b) => a.offTrail.compareTo(b.offTrail));
    final result = <Projection>[];
    for (final candidate in candidates) {
      if (candidate.offTrail > candidates.first.offTrail + 5) break;
      if (result.every((p) => (p.along - candidate.along).abs() > 75)) {
        result.add(candidate);
      }
      if (result.length == 6) break;
    }
    return result;
  }

  List<ProfilePoint> orientedProfile(bool reverse) => reverse
      ? profile.reversed
            .map(
              (p) => ProfilePoint(total - p.distance, p.elevation, p.segment),
            )
            .toList()
      : profile;
  double remaining(Projection p, bool reverse) =>
      reverse ? p.along : total - p.along;
}

class TrackingSession {
  TrackingSession(this.geometry);
  final TrailGeometry geometry;
  bool reverse = false, muted = false, active = false, offTrail = false;
  Projection? projection;
  Fix? fix;
  DateTime? _lastTime;
  int _outside = 0;
  double? startAlong;
  void resume() {
    active = true;
    fix = null;
    projection = null;
    muted = false;
    _lastTime = null;
    _outside = 0;
    offTrail = false;
  }

  void pause() {
    active = false;
    _lastTime = null;
  }

  void invert() {
    reverse = !reverse;
    startAlong = projection?.along;
  }

  bool accept(Fix value, DateTime now) {
    if (!active) return false;
    fix = value;
    if (!value.reliable(now) ||
        (_lastTime != null && !value.time.isAfter(_lastTime!))) {
      return false;
    }
    final elapsed = _lastTime == null
        ? null
        : value.time.difference(_lastTime!).inMilliseconds / 1000;
    projection = geometry.project(
      value.point,
      previous: elapsed == null ? null : projection?.along,
      maxTravel: elapsed == null
          ? double.infinity
          : 5 * elapsed + value.accuracy * 2 + 20,
    );
    _lastTime = value.time;
    startAlong ??= projection?.along;
    final gap = projection?.offTrail;
    if (gap == null) return false;
    if (gap > 35 + value.accuracy) {
      _outside++;
    } else if (gap < 20 + value.accuracy) {
      _outside = 0;
      offTrail = false;
    }
    if (_outside >= 3 && !offTrail) {
      offTrail = true;
      return !muted;
    }
    return false;
  }
}
