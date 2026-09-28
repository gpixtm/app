import 'dart:math' as math;

import 'heading.dart';
import 'models.dart';
import 'trail_geometry.dart';

enum GuidanceKind {
  slightLeft,
  left,
  sharpLeft,
  uTurnLeft,
  slightRight,
  right,
  sharpRight,
  uTurnRight,
  arrive,
  reachTrail,
  offTrail;

  bool get turn => index <= uTurnRight.index;

  GuidanceKind get mirrored => switch (this) {
    slightLeft => slightRight,
    left => right,
    sharpLeft => sharpRight,
    uTurnLeft => uTurnRight,
    slightRight => slightLeft,
    right => left,
    sharpRight => sharpLeft,
    uTurnRight => uTurnLeft,
    _ => this,
  };
}

/// A direction change at a distance on the shared trail axis (forward order).
class Maneuver {
  const Maneuver(this.along, this.kind, this.angle);
  final double along;
  final GuidanceKind kind;

  /// Signed turn in degrees, positive clockwise (right) when walking forward.
  final double angle;
}

/// A spoken/notified instruction. [metres] is null when the action is immediate.
class GuidanceInstruction {
  const GuidanceInstruction(this.kind, [this.metres]);
  final GuidanceKind kind;
  final int? metres;
  @override
  bool operator ==(Object other) =>
      other is GuidanceInstruction &&
      other.kind == kind &&
      other.metres == metres;
  @override
  int get hashCode => Object.hash(kind, metres);
  @override
  String toString() => 'GuidanceInstruction($kind, $metres)';
}

GuidanceKind? classifyTurn(double angle) {
  final size = angle.abs();
  if (size < 35) return null;
  final right = angle > 0;
  if (size < 60) {
    return right ? GuidanceKind.slightRight : GuidanceKind.slightLeft;
  }
  if (size < 130) return right ? GuidanceKind.right : GuidanceKind.left;
  if (size < 165) {
    return right ? GuidanceKind.sharpRight : GuidanceKind.sharpLeft;
  }
  return right ? GuidanceKind.uTurnRight : GuidanceKind.uTurnLeft;
}

class _Sample {
  const _Sample(this.along, this.x, this.y);
  final double along, x, y;
}

/// Detect direction changes inside each GPX segment. Segment gaps never create
/// a turn. Bearings use windows of [window] metres to absorb recorded GPS noise.
List<Maneuver> detectManeuvers(
  TrailGeometry geometry, {
  double step = 5,
  double window = 25,
  double merge = 30,
}) {
  final result = <Maneuver>[];
  final reach = (window / step).round();
  var offset = 0;
  // Maneuvers from an earlier segment are never merged across a GPX gap.
  var merged = 0;
  for (final segment in geometry.trail.segments) {
    final base = offset;
    offset += segment.length;
    if (segment.length < 2) continue;
    final samples = _resample(segment, [
      for (var i = 0; i < segment.length; i++)
        geometry.profile[base + i].distance,
    ], step);
    Maneuver? peak;
    void keep() {
      if (peak == null) return;
      final last = result.lastOrNull;
      if (last != null &&
          result.length > merged &&
          peak!.along - last.along < merge) {
        if (peak!.angle.abs() > last.angle.abs()) result.last = peak!;
      } else {
        result.add(peak!);
      }
      peak = null;
    }

    for (var i = reach; i + reach < samples.length; i++) {
      final before = samples[i - reach], at = samples[i];
      final after = samples[i + reach];
      final angle = angleDifference(_bearing(at, after), _bearing(before, at));
      final kind = classifyTurn(angle);
      if (kind == null || (peak != null && peak!.angle.sign != angle.sign)) {
        keep();
      }
      if (kind != null && (peak == null || angle.abs() > peak!.angle.abs())) {
        peak = Maneuver(at.along, kind, angle);
      }
    }
    keep();
    merged = result.length;
  }
  return result;
}

List<_Sample> _resample(
  List<GeoPoint> points,
  List<double> alongs,
  double step,
) {
  final origin = points.first;
  final scale = math.cos(origin.lat * math.pi / 180) * 111319.49;
  double x(GeoPoint p) => (p.lon - origin.lon) * scale;
  double y(GeoPoint p) => (p.lat - origin.lat) * 111319.49;
  final samples = <_Sample>[];
  var target = alongs.first;
  for (var i = 1; i < points.length; i++) {
    final start = alongs[i - 1], end = alongs[i];
    if (end <= start) continue;
    while (target <= end) {
      final f = (target - start) / (end - start);
      final a = points[i - 1], b = points[i];
      samples.add(
        _Sample(target, x(a) + (x(b) - x(a)) * f, y(a) + (y(b) - y(a)) * f),
      );
      target += step;
    }
  }
  return samples;
}

double _bearing(_Sample a, _Sample b) =>
    (math.atan2(b.x - a.x, b.y - a.y) * 180 / math.pi + 360) % 360;

/// Delivers turn-by-turn instructions (voice, notification) outside the UI.
abstract interface class GuidanceOutput {
  /// Request delivery permissions. False only means notifications are blocked.
  Future<bool> prepare();
  Future<void> announce(
    GuidanceInstruction instruction, {
    required bool speak,
    required bool notify,
  });
  Future<void> clear();
}
