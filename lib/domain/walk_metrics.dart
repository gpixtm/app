import 'dart:math' as math;

import 'models.dart';
import 'trail_geometry.dart';

class WalkMetrics {
  WalkMetrics(Trail trail, {DateTime? now}) {
    metres = TrailGeometry(trail).total;
    // Times and speeds exist for walks only; a trail has length and climb.
    if (trail.walk case final walk?) {
      activeSeconds = walk.seconds;
      elapsedSeconds = (walk.ended ?? now ?? DateTime.now())
          .difference(walk.started)
          .inSeconds
          .clamp(0, 1 << 30);
      if (activeSeconds > 0 && metres > 0) {
        averageKmh = metres / activeSeconds * 3.6;
        paceSeconds = activeSeconds / (metres / 1000);
      }
      final samples = walk.samples;
      for (var i = 1; i < samples.length; i++) {
        final a = samples[i - 1], b = samples[i];
        final seconds = b.time.difference(a.time).inMilliseconds / 1000;
        if (a.segment != b.segment || seconds <= 0 || seconds > 30) continue;
        final speed = distance(a.point, b.point) / seconds;
        if (speed <= 7) maxKmh = math.max(maxKmh ?? 0, speed * 3.6);
      }
    }
    // Three-metre hysteresis avoids summing each small altitude fluctuation.
    for (final segment in trail.segments) {
      double? anchor;
      for (final p in segment) {
        final altitude = p.elevation;
        if (altitude == null || !altitude.isFinite) {
          anchor = null;
          continue;
        }
        minimumAltitude = math.min(minimumAltitude ?? altitude, altitude);
        maximumAltitude = math.max(maximumAltitude ?? altitude, altitude);
        lastAltitude = altitude;
        anchor ??= altitude;
        final delta = altitude - anchor;
        if (delta.abs() >= 3) {
          if (delta > 0) {
            ascent += delta;
          } else {
            descent -= delta;
          }
          anchor = altitude;
        }
      }
    }
  }
  double metres = 0, ascent = 0, descent = 0;
  int activeSeconds = 0, elapsedSeconds = 0;
  double? averageKmh,
      maxKmh,
      paceSeconds,
      minimumAltitude,
      maximumAltitude,
      lastAltitude;
  bool get hasElevation => lastAltitude != null;
}

/// Active seconds since the start at each of [walk]'s samples. A pause adds
/// no time; a GPS gap adds the time its distance takes at the walk's average
/// speed.
List<double> activeTimeline(Trail walk) {
  final details = walk.walk!;
  final samples = details.samples;
  final metres = TrailGeometry(walk).total;
  final speed = details.seconds > 0 && metres > 0
      ? metres / details.seconds
      : 1.3;
  final result = <double>[];
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
    result.add(active);
  }
  return result;
}
