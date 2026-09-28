import 'dart:math' as math;

import 'models.dart';

/// Douglas–Peucker simplification in a local metric projection, keeping both
/// ends of each line. The tolerance doubles until at most [maximumPoints]
/// remain, so a long trail stays light while its shape stays recognizable.
List<List<GeoPoint>> simplifyLines(
  List<List<GeoPoint>> lines, {
  double tolerance = 5,
  int maximumPoints = 5000,
}) {
  final usable = [
    for (final line in lines)
      if (line.length > 1) line,
  ];
  var result = usable;
  for (var t = tolerance, round = 0; round < 16; t *= 2, round++) {
    result = [for (final line in usable) _simplify(line, t)];
    if (result.fold(0, (n, line) => n + line.length) <= maximumPoints) break;
  }
  return result;
}

List<GeoPoint> _simplify(List<GeoPoint> line, double tolerance) {
  if (line.length < 3) return line;
  final scale = math.cos(line.first.lat * math.pi / 180) * 111320;
  final xs = [for (final p in line) p.lon * scale];
  final ys = [for (final p in line) p.lat * 110574];
  final keep = List.filled(line.length, false)
    ..[0] = true
    ..[line.length - 1] = true;
  final stack = [(0, line.length - 1)];
  while (stack.isNotEmpty) {
    final (first, last) = stack.removeLast();
    final dx = xs[last] - xs[first], dy = ys[last] - ys[first];
    final length = dx * dx + dy * dy;
    var index = -1;
    var furthest = tolerance;
    for (var i = first + 1; i < last; i++) {
      final t = length > 0
          ? (((xs[i] - xs[first]) * dx + (ys[i] - ys[first]) * dy) / length)
                .clamp(0.0, 1.0)
          : 0.0;
      final d = math.sqrt(
        math.pow(xs[i] - (xs[first] + t * dx), 2) +
            math.pow(ys[i] - (ys[first] + t * dy), 2),
      );
      if (d > furthest) {
        furthest = d;
        index = i;
      }
    }
    if (index < 0) continue;
    keep[index] = true;
    stack
      ..add((first, index))
      ..add((index, last));
  }
  return [
    for (var i = 0; i < line.length; i++)
      if (keep[i]) line[i],
  ];
}
