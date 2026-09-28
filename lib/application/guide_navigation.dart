import '../domain/guidance.dart';
import '../domain/trail_geometry.dart';

class UpcomingManeuver {
  const UpcomingManeuver(this.kind, this.metres, this.along);
  final GuidanceKind kind;
  final double metres;
  final double along;
}

/// Announces each direction change once when approaching it, then again when
/// it is immediate. Works from GPS fixes alone, so it also runs screen-off.
class GuideNavigation {
  GuideNavigation(
    this.output, {
    this.voice = true,
    this.announceDistance = 100,
    this.immediateDistance = 20,
    this.arrivalDistance = 30,
  });
  final GuidanceOutput output;
  final double announceDistance, immediateDistance, arrivalDistance;
  bool voice;

  TrailGeometry? _geometry;
  List<Maneuver> _maneuvers = const [];
  bool? _reverse;
  final Set<String> _announced = {};
  bool _posted = false;

  List<Maneuver> maneuvers(TrailGeometry geometry) {
    if (!identical(geometry, _geometry)) {
      _geometry = geometry;
      _maneuvers = detectManeuvers(geometry);
      _announced.clear();
    }
    return _maneuvers;
  }

  /// Next maneuver ahead in the walking direction, including the final arrival.
  UpcomingManeuver? upcoming(TrackingSession session, {bool approach = false}) {
    final p = session.projection;
    if (p == null) return null;
    final reverse = session.reverse;
    final list = maneuvers(session.geometry);
    Maneuver? next;
    if (reverse) {
      next = list.lastWhereOrNull((m) => m.along < p.along - 5);
    } else {
      next = list.firstWhereOrNull((m) => m.along > p.along + 5);
    }
    if (next != null) {
      return UpcomingManeuver(
        reverse ? next.kind.mirrored : next.kind,
        (next.along - p.along).abs(),
        next.along,
      );
    }
    final end = reverse ? 0.0 : session.geometry.total;
    return UpcomingManeuver(
      approach ? GuidanceKind.reachTrail : GuidanceKind.arrive,
      (end - p.along).abs(),
      end,
    );
  }

  Future<void> update(
    TrackingSession session, {
    required bool approach,
    required bool leftTrail,
    required bool foreground,
    required DateTime now,
  }) async {
    if (!session.active) return;
    maneuvers(session.geometry);
    if (_reverse != session.reverse) {
      _reverse = session.reverse;
      _announced.clear();
    }
    if (leftTrail) {
      await _say(const GuidanceInstruction(GuidanceKind.offTrail), foreground);
      return;
    }
    final fix = session.fix;
    if (session.offTrail || fix == null || !fix.reliable(now)) return;
    final next = upcoming(session, approach: approach);
    if (next == null) return;
    final key = '${next.kind.turn ? 'turn' : 'end'}:${next.along}';
    if (!next.kind.turn) {
      final start = session.startAlong;
      final progressed =
          start != null && (next.along - start).abs() > 2 * arrivalDistance;
      if (next.metres <= arrivalDistance && progressed && _announced.add(key)) {
        await _say(GuidanceInstruction(next.kind), foreground);
      }
      return;
    }
    if (next.metres <= immediateDistance) {
      _announced.add('$key:far');
      if (_announced.add('$key:now')) {
        await _say(GuidanceInstruction(next.kind), foreground);
      }
    } else if (next.metres < announceDistance + 5 &&
        _announced.add('$key:far')) {
      // Spoken distances are rounded to 10 m, so tolerate GPS/axis rounding.
      final metres = ((next.metres / 10).round() * 10).clamp(
        10,
        announceDistance.round(),
      );
      await _say(GuidanceInstruction(next.kind, metres), foreground);
    }
  }

  Future<bool> prepare() async {
    try {
      return await output.prepare();
    } catch (_) {
      return false;
    }
  }

  /// Leave guidance: forget announcements and remove any posted instruction.
  Future<void> leave() async {
    _announced.clear();
    _reverse = null;
    if (!_posted) return;
    _posted = false;
    try {
      await output.clear();
    } catch (_) {}
  }

  Future<void> _say(GuidanceInstruction instruction, bool foreground) async {
    // The visible map already shows the instruction; notify only off-screen.
    if (!foreground) _posted = true;
    try {
      await output.announce(instruction, speak: voice, notify: !foreground);
    } catch (_) {
      // Guidance delivery must never interrupt position tracking.
    }
  }
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }

  T? lastWhereOrNull(bool Function(T) test) {
    for (final value in reversed) {
      if (test(value)) return value;
    }
    return null;
  }
}
