import 'app_message.dart';

import 'dart:math' as math;

import 'models.dart';

/// A bounded piece of the map pyramid; vectors above zoom 14 are overzoomed.
class MapArea {
  const MapArea(this.gridZoom, this.x, this.y, this.maxZoom);
  final int gridZoom, x, y, maxZoom;
  String get key => '$gridZoom/$x/$y/$maxZoom';
  Bounds get bounds {
    final n = math.pow(2, gridZoom).toDouble();
    double latitude(int y) =>
        math.atan(_sinh(math.pi * (1 - 2 * y / n))) * 180 / math.pi;
    return Bounds(
      x / n * 360 - 180,
      latitude(y + 1),
      (x + 1) / n * 360 - 180,
      latitude(y),
    );
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
  static MapArea parse(String key) {
    final p = key.split('/').map(int.parse).toList();
    if (p.length != 4 ||
        p[0] < 0 ||
        p[0] > 14 ||
        p[3] < p[0] ||
        p[3] > 14 ||
        p[1] < 0 ||
        p[2] < 0 ||
        p[1] >= 1 << p[0] ||
        p[2] >= 1 << p[0]) {
      throw MessageFormatException(AppMessage.invalidMapArea);
    }
    return MapArea(p[0], p[1], p[2], p[3]);
  }
}

class MapPlan {
  static (double, double) _tile(GeoPoint p, int z) {
    final n = (1 << z).toDouble(),
        lat = p.lat.clamp(-85.051128, 85.051128) * math.pi / 180;
    return (
      (p.lon + 180) / 360 * n,
      (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n,
    );
  }

  /// Follow every segment, including long edges with sparse GPX points. A ring
  /// of neighbouring cells leaves room to step off the route. Gaps stay gaps.
  static List<MapArea> trail(Trail trail) {
    const z = 13, n = 1 << z;
    final result = <String, MapArea>{};
    void add(double x, double y) {
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final row = y.floor() + dy;
          if (row < 0 || row >= n) continue;
          final area = MapArea(z, (x.floor() + dx) % n, row, 14);
          result[area.key] = area;
        }
      }
    }

    for (final segment in trail.segments) {
      (double, double)? previous;
      for (final p in segment) {
        final t = _tile(p, z);
        add(t.$1, t.$2);
        if (previous != null) {
          var dx = t.$1 - previous.$1;
          if (dx.abs() > n / 2) dx -= dx.sign * n;
          final dy = t.$2 - previous.$2;
          final steps = (math.max(dx.abs(), dy.abs()) * 2).ceil();
          for (var i = 1; i < steps; i++) {
            add(previous.$1 + dx * i / steps, previous.$2 + dy * i / steps);
          }
        }
        previous = t;
      }
    }
    for (final poi in trail.pois) {
      final t = _tile(poi.point, z);
      add(t.$1, t.$2);
    }
    return result.values.toList();
  }

  /// Quantisation avoids creating a new offline region for each camera pixel.
  static List<MapArea> viewport(Bounds b, double zoom) {
    final maxZoom = zoom.ceil().clamp(0, 14);
    var grid = (maxZoom - 2).clamp(0, 12);
    while (true) {
      final n = 1 << grid;
      final nw = _tile(GeoPoint(b.north, b.west), grid);
      final se = _tile(GeoPoint(b.south, b.east), grid);
      final west = nw.$1.floor().clamp(0, n - 1),
          east = se.$1.floor().clamp(0, n - 1);
      final north = nw.$2.floor().clamp(0, n - 1),
          south = se.$2.floor().clamp(0, n - 1);
      final columns = b.west > b.east ? n - west + east + 1 : east - west + 1;
      if (columns * (south - north + 1) > 32 && grid > 0) {
        grid--;
        continue;
      }
      return [
        for (var col = 0; col < columns; col++)
          for (var row = north; row <= south; row++)
            MapArea(grid, (west + col) % n, row, math.min(maxZoom, grid + 2)),
      ];
    }
  }
}

class StoredMapArea {
  const StoredMapArea(this.area, this.ready);
  final MapArea area;
  final bool ready;
}

abstract interface class AutomaticMapStore {
  String get style;
  Future<List<StoredMapArea>> restore();
  Future<void> remember(List<MapArea> areas);
  Future<void> download(MapArea area, void Function(double) progress);
  Future<void> close();
}
