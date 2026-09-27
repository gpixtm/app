import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/prepare_maps.dart';
import 'package:gpix/domain/automatic_maps.dart';
import 'package:gpix/domain/models.dart';

class Store implements AutomaticMapStore {
  List<MapArea> saved = [];
  final ready = <String>{};
  final requests = <String>[];
  bool online = true;
  @override
  String get style => 'https://maps.test/style';
  @override
  Future<List<StoredMapArea>> restore() async => [
    for (final a in saved) StoredMapArea(a, ready.contains(a.key)),
  ];
  @override
  Future<void> remember(List<MapArea> areas) async {
    saved = areas;
  }

  @override
  Future<void> download(MapArea area, void Function(double) progress) async {
    requests.add(area.key);
    if (!online) throw StateError('offline');
    ready.add(area.key);
    progress(1);
  }

  @override
  Future<void> close() async {}
}

Trail route(List<List<GeoPoint>> segments) =>
    Trail(id: 'test', name: 'GPX', segments: segments, pois: []);
Future<void> settle(PrepareMaps maps) async {
  for (var i = 0; i < 100 && maps.pendingCount > 0 && maps.error == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  test('GPX corridor fills sparse edges, preserves gaps and deduplicates', () {
    final connected = MapPlan.trail(
      route([
        [const GeoPoint(49.25, 4.03), const GeoPoint(48.85, 2.35)],
      ]),
    );
    final gaps = MapPlan.trail(
      route([
        [const GeoPoint(49.25, 4.03)],
        [const GeoPoint(48.85, 2.35)],
      ]),
    );
    expect(connected.length, greaterThan(gaps.length * 2));
    expect(connected.map((a) => a.key).toSet().length, connected.length);
    expect(
      connected.any((a) => a.bounds.contains(const GeoPoint(49.05, 3.19))),
      isTrue,
    );
    expect(
      gaps.any((a) => a.bounds.contains(const GeoPoint(49.05, 3.19))),
      isFalse,
    );
    expect(connected.every((a) => a.maxZoom == 14), isTrue);
  });
  test('antimeridian GPX follows the short edge; world zoom does not download street detail', () {
    final areas = MapPlan.trail(
      route([
        [const GeoPoint(0, 179.99), const GeoPoint(0, -179.99)],
      ]),
    );
    expect(areas.length, lessThan(30));
    final world = MapPlan.viewport(const Bounds(-180, -85, 180, 85), 1);
    expect(world.length, 1);
    expect(world.single.maxZoom, 1);
    final inconsistent = MapPlan.viewport(const Bounds(-180, -85, 180, 85), 18);
    expect(inconsistent.length, lessThanOrEqualTo(32));
    expect(inconsistent.every((a) => a.maxZoom <= a.gridZoom + 2), isTrue);
  });
  test('offline import persists intended zones, restart resumes, ready zones are not fetched again', () async {
    final store = Store()..online = false;
    final trail = route([
      [const GeoPoint(49.25, 4.03), const GeoPoint(49.251, 4.031)],
    ]);
    final first = PrepareMaps(store);
    await first.initialize();
    await first.trails([trail]);
    await settle(first);
    expect(store.saved, isNotEmpty);
    expect(first.covers(trail), isFalse);
    expect(first.error, isNotNull);
    await first.close();
    store.online = true;
    final second = PrepareMaps(store);
    await second.initialize();
    await second.trails([trail]);
    await settle(second);
    expect(second.covers(trail), isTrue);
    final count = store.requests.length;
    await second.trails([trail]);
    await settle(second);
    expect(store.requests.length, count);
    await second.close();
    final third = PrepareMaps(store);
    await third.initialize();
    expect(third.pendingCount, 0);
    await third.close();
  });
  test('camera moves and zooms enqueue new areas automatically without duplicating identical view', () async {
    final store = Store(), maps = PrepareMaps(Store());
    await maps.close();
    final queue = PrepareMaps(store);
    await queue.initialize();
    const reims = Bounds(4.02, 49.24, 4.04, 49.26);
    await queue.viewport(reims, 13);
    await settle(queue);
    final first = store.requests.length;
    await queue.viewport(reims, 13);
    expect(store.requests.length, first);
    await queue.viewport(const Bounds(2.34, 48.84, 2.36, 48.86), 15);
    await settle(queue);
    expect(store.requests.length, greaterThan(first));
    await queue.close();
  });
}
