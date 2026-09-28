import 'dart:math' as math;

import 'models.dart';
import 'trail_geometry.dart';

enum WalkedRouteOutcome { created, alreadyKnown, tooShort }

class WalkedRoute {
  const WalkedRoute(this.outcome, [this.trail]);

  /// The new route when [outcome] is created, the followed one when known.
  final WalkedRouteOutcome outcome;
  final Trail? trail;
}

/// Shortest recorded distance that makes a reusable route.
const minimumRouteMetres = 50.0;

/// GPS noise allowed before a walked point counts as leaving a route.
const routeTolerance = 30.0;

/// A free walk becomes a reusable route, unless it stays entirely on an
/// existing one. Any stretch beyond [tolerance] is a modification and
/// therefore a new route. Recorded segments stay separate: pauses and GPS gaps
/// never become imaginary lines.
WalkedRoute routeFromWalk(
  Trail walk,
  Iterable<Trail> known, {
  required String id,
  required String name,
  double tolerance = routeTolerance,
}) {
  final segments = walk.segments.where((s) => s.length > 1).toList();
  final route = Trail(id: id, name: name, segments: segments, pois: const []);
  if (TrailGeometry(route).total < minimumRouteMetres) {
    return const WalkedRoute(WalkedRouteOutcome.tooShort);
  }
  for (final trail in known) {
    if (trail.walk == null && follows(route, trail, tolerance: tolerance)) {
      return WalkedRoute(WalkedRouteOutcome.alreadyKnown, trail);
    }
  }
  return WalkedRoute(WalkedRouteOutcome.created, route);
}

/// Whether every point of [walk] lies within [tolerance] of [trail], between
/// vertices included.
bool follows(Trail walk, Trail trail, {double tolerance = routeTolerance}) {
  if (!trail.followable || !walk.points.any((_) => true)) return false;
  // Metres to degrees, generous enough for any latitude used by walkers.
  final margin = tolerance / 111320 / math.max(.2, _cos(walk.points.first));
  final box = _bounds(trail.points);
  if (walk.points.any(
    (p) =>
        p.lat < box.south - margin ||
        p.lat > box.north + margin ||
        p.lon < box.west - margin ||
        p.lon > box.east + margin,
  )) {
    return false;
  }
  final geometry = TrailGeometry(trail);
  for (final point in walk.points) {
    final projection = geometry.project(point);
    if (projection == null || projection.offTrail > tolerance) return false;
  }
  return true;
}

double _cos(GeoPoint p) => math.cos(p.lat * math.pi / 180);

Bounds _bounds(Iterable<GeoPoint> points) {
  var west = double.infinity, south = double.infinity;
  var east = -double.infinity, north = -double.infinity;
  for (final p in points) {
    west = math.min(west, p.lon);
    east = math.max(east, p.lon);
    south = math.min(south, p.lat);
    north = math.max(north, p.lat);
  }
  return Bounds(west, south, east, north);
}
