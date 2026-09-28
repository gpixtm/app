import 'dart:math' as math;

import 'models.dart';
import 'shared_trails.dart';
import 'text_folding.dart';
import 'trail_geometry.dart';

/// What attaching does with one point of a points file.
enum PointFate {
  /// Becomes a new place of the trail, shared with everyone.
  added,

  /// The trail already has this place: the point leaves the file, no copy.
  known,

  /// More than [maximumImportedPlaceDistance] from every trail: it stays in
  /// the file.
  tooFar,

  /// Neither a name nor a description to name a place: it stays in the file.
  unnamed,
}

/// One point of a points file and what attaching does with it.
class PlannedPoint {
  const PlannedPoint(
    this.poi,
    this.source,
    this.fate, {
    this.trail,
    this.name = '',
    this.comment = '',
  });
  final Poi poi;

  /// Identifier of the points file it comes from.
  final String source;
  final PointFate fate;

  /// The nearest trail, for a point added or already known.
  final Trail? trail;

  /// Name and comment of the place it becomes.
  final String name, comment;
}

/// A trail the walker may attach points to, with how many of them lie close
/// enough.
class AttachTarget {
  const AttachTarget(this.trail, this.inRange, {this.catalogue = false});
  final Trail trail;
  final int inRange;

  /// A shared trail not on this phone, found around the points.
  final bool catalogue;
}

/// Points files attached to trails: each point becomes a public place of the
/// nearest trail within [maximumImportedPlaceDistance]. The points left out
/// stay in their file, so nothing the walker imported is lost.
class PointAttachment {
  const PointAttachment(this.sources, this.targets, this.points);
  final List<Trail> sources, targets;
  final List<PlannedPoint> points;

  int count(PointFate fate) => points.where((p) => p.fate == fate).length;

  /// Whether attaching changes anything: at least one point finds its trail.
  bool get attachesAny =>
      points.any((p) => p.fate == PointFate.added || p.fate == PointFate.known);
  Iterable<PlannedPoint> get added =>
      points.where((p) => p.fate == PointFate.added);

  /// Each file with only the points left out; the files left empty go.
  List<Trail> get remaining => [
    for (final source in sources)
      if (_left(source).isNotEmpty) source.withPois(_left(source)),
  ];
  List<String> get emptied => [
    for (final source in sources)
      if (_left(source).isEmpty) source.id,
  ];
  List<Poi> _left(Trail source) => [
    for (final p in points)
      if (p.source == source.id &&
          (p.fate == PointFate.tooFar || p.fate == PointFate.unnamed))
        p.poi,
  ];

  /// Attach the points of [sources] to the nearest of [targets]. A point
  /// close to a place the trail already has, [places] included, with an
  /// equivalent name, is known rather than added twice.
  static PointAttachment plan(
    List<Trail> sources,
    List<Trail> targets,
    List<TrailPlace> places,
  ) {
    final reaches = [
      for (final t in targets)
        if (t.followable) _Reach(t),
    ];
    final existing = <_Reach, List<(GeoPoint, String)>>{
      for (final r in reaches)
        r: [
          for (final p in places)
            if (!p.deleted &&
                (p.trailId == r.trail.id || p.trailId == r.trail.sharedId))
              (p.point, placeNameKey(p.name)),
        ],
    };
    final points = <PlannedPoint>[];
    for (final source in sources) {
      for (final poi in source.pois) {
        final (name, comment) = _placeText(poi);
        if (name.isEmpty) {
          points.add(PlannedPoint(poi, source.id, PointFate.unnamed));
          continue;
        }
        _Reach? nearest;
        var best = double.infinity;
        for (final r in reaches) {
          final gap = r.distance(poi.point);
          if (gap != null && gap < best) (nearest, best) = (r, gap);
        }
        if (nearest == null) {
          points.add(PlannedPoint(poi, source.id, PointFate.tooFar));
          continue;
        }
        final key = placeNameKey(name);
        final known = existing[nearest]!.any(
          (e) =>
              e.$2 == key &&
              distance(e.$1, poi.point) <= duplicatePlaceDistance,
        );
        if (!known) existing[nearest]!.add((poi.point, key));
        points.add(
          PlannedPoint(
            poi,
            source.id,
            known ? PointFate.known : PointFate.added,
            trail: nearest.trail,
            name: name,
            comment: comment,
          ),
        );
      }
    }
    return PointAttachment(sources, targets, points);
  }

  /// A waypoint without a name takes the first line of its description.
  static (String, String) _placeText(Poi poi) {
    final name = poi.name.trim();
    final description = poi.description.trim();
    if (name.isNotEmpty) {
      return (
        _truncate(name, maximumPlaceNameLength),
        _truncate(description, maximumReviewLength),
      );
    }
    final line = description.split('\n').first.trim();
    return (_truncate(line, maximumPlaceNameLength), '');
  }

  /// At most [length] characters, counted like the API does.
  static String _truncate(String text, int length) =>
      text.runes.length <= length
      ? text
      : String.fromCharCodes(text.runes.take(length)).trimRight();
}

/// How many of [points] lie within [maximumImportedPlaceDistance] of [trail].
int pointsInRange(Iterable<GeoPoint> points, Trail trail) {
  if (!trail.followable) return 0;
  final reach = _Reach(trail);
  return points.where((p) => reach.distance(p) != null).length;
}

/// The name places are compared by: case, accents, spaces and punctuation
/// ignored. A name without letters or digits, such as an emoji, compares as
/// written.
String placeNameKey(String name) {
  final key = foldForSearch(name)
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
  return key.isEmpty ? name.trim().toLowerCase() : key;
}

/// A trail and the area within [maximumImportedPlaceDistance] of it, so most
/// far points are ruled out without measuring along the whole line.
class _Reach {
  _Reach(this.trail) : geometry = TrailGeometry(trail) {
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final p in trail.points) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lon);
      east = math.max(east, p.lon);
    }
    final margin = maximumImportedPlaceDistance / 110574;
    final lonMargin =
        margin /
        math.max(
          .01,
          math.cos(math.max(south.abs(), north.abs()) * math.pi / 180),
        );
    area = Bounds(
      west - lonMargin,
      south - margin,
      east + lonMargin,
      north + margin,
    );
  }
  final Trail trail;
  final TrailGeometry geometry;
  late final Bounds area;

  /// Metres from [p] to the line, or null beyond reach.
  double? distance(GeoPoint p) {
    if (!area.contains(p)) return null;
    final gap = geometry.project(p)?.offTrail;
    return gap == null || gap > maximumImportedPlaceDistance ? null : gap;
  }
}
