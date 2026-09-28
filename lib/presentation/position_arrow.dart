import 'dart:math' as math;

import '../domain/models.dart';
import 'map_features.dart';

/// Map colour of the walker's direction arrow.
const positionArrowHex = '#2563eb';

const _earthRadius = 6371008.8;

/// Ground metres covered by one logical pixel of the map at [zoom] and
/// [latitude]; the map uses 512-pixel tiles.
double metresPerPixel(double zoom, double latitude) =>
    2 *
    math.pi *
    _earthRadius *
    math.cos(latitude * math.pi / 180) /
    (512 * math.pow(2, zoom));

/// The walker's direction arrow as map polygons: a soft beam showing where
/// the walker faces, then a compact navigation chevron whose visual centre is
/// the position itself. Polygons move with the map on every update, whereas a
/// map icon replaced at each position fades in again and flickers. Sizes are
/// logical pixels converted with [metresPerPixel], so the arrow keeps its size
/// on screen; [bearing] is clockwise from north in degrees.
List<Map<String, dynamic>> positionArrowFeatures(
  GeoPoint position,
  double bearing,
  double metresPerPixel,
) {
  final angle = bearing * math.pi / 180;
  final forward = (east: math.sin(angle), north: math.cos(angle));
  final right = (east: math.cos(angle), north: -math.sin(angle));
  final latitude = position.lat * math.pi / 180;
  // (x, y) are screen-like offsets for an arrow pointing up: y grows downwards.
  List<double> at(double x, double y) {
    final east = (x * right.east - y * forward.east) * metresPerPixel;
    final north = (x * right.north - y * forward.north) * metresPerPixel;
    return [
      position.lon + east / (_earthRadius * math.cos(latitude)) * 180 / math.pi,
      position.lat + north / _earthRadius * 180 / math.pi,
    ];
  }

  // Nested sectors add up to a beam that fades away from the walker.
  const beamHalfAngle = 32 * math.pi / 180;
  List<List<double>> sector(double radius) => [
    at(0, 0),
    for (var i = 0; i <= 12; i++)
      at(
        radius * math.sin(-beamHalfAngle + beamHalfAngle * i / 6),
        -radius * math.cos(-beamHalfAngle + beamHalfAngle * i / 6),
      ),
    at(0, 0),
  ];
  final chevron = [at(0, -12), at(9.5, 10), at(0, 5), at(-9.5, 10), at(0, -12)];
  return [
    for (final (radius, opacity) in const [
      (30.0, .12),
      (20.0, .13),
      (10.0, .15),
    ])
      feature(
        'Polygon',
        [sector(radius)],
        {'part': 'beam', 'opacity': opacity},
      ),
    feature('Polygon', [chevron], {'part': 'arrow'}),
  ];
}
