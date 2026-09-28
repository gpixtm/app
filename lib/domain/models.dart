import 'dart:math' as math;

import 'day_plan.dart';
import 'walk_recording.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.lon, [this.elevation]);
  final double lat, lon;
  final double? elevation;
  bool get valid =>
      lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;
}

class Poi {
  const Poi(this.point, this.name, this.description);
  final GeoPoint point;
  final String name, description;
}

class Trail {
  Trail({
    required this.id,
    required this.name,
    required List<List<GeoPoint>> segments,
    required List<Poi> pois,
    this.description = '',
    this.estimated = false,
    List<WalkingDay> days = const [],
    this.walk,
    this.publicId,
  }) : segments = List.unmodifiable(segments.map(List<GeoPoint>.unmodifiable)),
       days = List.unmodifiable(days),
       pois = List.unmodifiable(pois);
  final List<WalkingDay> days;
  final WalkDetails? walk;
  Trail withWalk(WalkDetails value) => Trail(
    id: id,
    name: name,
    segments: segments,
    pois: pois,
    description: description,
    estimated: estimated,
    days: days,
    walk: value,
    publicId: publicId,
  );
  Trail withDays(List<WalkingDay> value) => Trail(
    id: id,
    name: name,
    segments: segments,
    pois: pois,
    description: description,
    estimated: estimated,
    days: value,
    walk: walk,
    publicId: publicId,
  );
  Trail withPublicId(String? value) => Trail(
    id: id,
    name: name,
    segments: segments,
    pois: pois,
    description: description,
    estimated: estimated,
    days: days,
    walk: walk,
    publicId: value,
  );
  Trail withPois(List<Poi> value) => Trail(
    id: id,
    name: name,
    segments: segments,
    pois: value,
    description: description,
    estimated: estimated,
    days: days,
    walk: walk,
    publicId: publicId,
  );

  /// Shared trail this library entry published or reused. It is kept beside
  /// the synced payload, never inside it. A line added on a phone usually
  /// already carries its shared identifier as [id].
  final String? publicId;
  String get sharedId => publicId ?? id;
  final String id, name, description;
  final List<List<GeoPoint>> segments;
  final List<Poi> pois;
  final bool estimated;
  bool get followable => segments.any((s) => s.length > 1);
  Iterable<GeoPoint> get points => segments.expand((s) => s);
}

class Fix {
  const Fix(this.point, this.accuracy, this.time, {this.heading});
  final GeoPoint point;
  final double accuracy;
  final DateTime time;
  final double? heading;
  bool reliable(DateTime now) =>
      point.valid &&
      accuracy.isFinite &&
      accuracy >= 0 &&
      accuracy <= 40 &&
      now.difference(time).inSeconds <= 15 &&
      !time.isAfter(now.add(const Duration(seconds: 5)));
}

class Bounds {
  const Bounds(this.west, this.south, this.east, this.north);
  final double west, south, east, north;
  bool contains(GeoPoint p) =>
      p.lon >= west && p.lon <= east && p.lat >= south && p.lat <= north;
}

double distance(GeoPoint a, GeoPoint b) {
  const rad = math.pi / 180;
  final x =
      math.pow(math.sin((b.lat - a.lat) * rad / 2), 2) +
      math.cos(a.lat * rad) *
          math.cos(b.lat * rad) *
          math.pow(math.sin((b.lon - a.lon) * rad / 2), 2);
  return 6371008.8 * 2 * math.asin(math.sqrt(x.clamp(0, 1)));
}
