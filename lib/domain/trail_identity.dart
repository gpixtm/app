import 'models.dart';

/// Content identity of a shared trail: its line geometry only, so the same GPX
/// renamed, re-exported or given elevations is the same trail. Coordinates are
/// quantized to 1e-5 degree with the IEEE-754 arithmetic the API uses
/// (`App\Domain\TrailFingerprint`); consecutive equal points collapse and
/// segments left without a line are ignored. Null when there is no line.
String? trailIdentityText(Iterable<List<GeoPoint>> segments) {
  final lines = <String>[];
  for (final segment in segments) {
    final points = <String>[];
    for (final p in segment) {
      final key = '${_quantize(p.lat)},${_quantize(p.lon)}';
      if (points.isEmpty || points.last != key) points.add(key);
    }
    if (points.length > 1) lines.add(points.join(';'));
  }
  return lines.isEmpty ? null : 'gpix-trail-v1\n${lines.join('\n')}';
}

int _quantize(double degrees) => (degrees * 100000 + .5).floor();

/// Hashes [trailIdentityText] into the fingerprint and identifier the API
/// derives too, so a line added on two phones shares one identity offline.
abstract interface class TrailIdentity {
  String? fingerprint(Iterable<List<GeoPoint>> segments);

  /// Name-based identifier of a new shared trail with this fingerprint.
  String sharedId(String fingerprint);
}
