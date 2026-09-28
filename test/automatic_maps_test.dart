import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/prepare_maps.dart';
import 'package:gpix/domain/automatic_maps.dart';
import 'package:gpix/domain/models.dart';

class Store implements AutomaticMapStore {
  List<MapArea> saved = [];
  final ready = <String>{};
  final recordedReady = <String>{};
  final requests = <String>[];
  bool online = true;
  Future<void>? restoring;
  @override
  String get style => 'https://maps.test/style';
  @override
  Future<List<StoredMapArea>> restore() async {
    await restoring;
    return [for (final a in saved) StoredMapArea(a, ready.contains(a.key))];
  }

  @override
  Future<void> remember(List<StoredMapArea> areas) async {
    saved = [for (final a in areas) a.area];
    recordedReady
      ..clear()
      ..addAll([
        for (final a in areas)
          if (a.ready) a.area.key,
      ]);
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
  test('completed areas are recorded ready for the next launch', () async {
    final store = Store();
    final maps = PrepareMaps(store);
    await maps.initialize();
    await maps.viewport(const Bounds(4.02, 49.24, 4.04, 49.26), 13);
    await settle(maps);
    await maps.close();
    expect(store.saved, isNotEmpty);
    expect(store.recordedReady, store.saved.map((a) => a.key).toSet());
  });
  test('requests made while the queue restores keep the saved areas', () async {
    final store = Store();
    final trail = route([
      [const GeoPoint(49.25, 4.03), const GeoPoint(49.251, 4.031)],
    ]);
    store.saved = MapPlan.trail(trail);
    final saved = store.saved.map((a) => a.key).toSet();
    final gate = Completer<void>();
    store.restoring = gate.future;
    final maps = PrepareMaps(store);
    final restoring = maps.initialize();
    final moved = maps.viewport(const Bounds(2.34, 48.84, 2.36, 48.86), 15);
    await Future<void>.delayed(Duration.zero);
    expect(store.saved.map((a) => a.key).toSet(), saved);
    gate.complete();
    await restoring;
    await moved;
    expect(store.saved.map((a) => a.key).toSet().containsAll(saved), isTrue);
    expect(store.saved.length, greaterThan(saved.length));
    await maps.close();
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
