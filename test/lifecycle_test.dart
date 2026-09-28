import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/presentation/app.dart';
import 'package:flutter/material.dart';

class Repository implements TrailRepository {
  final List<Trail> list = [];
  @override
  Future<List<Trail>> all() async => list;
  @override
  Future<Trail?> find(String id) async =>
      list.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> delete(String id) async => list.removeWhere((t) => t.id == id);
  @override
  Future<void> save(Trail t) async {
    list.add(t);
  }

  @override
  Future<void> keep(Trail t) async {
    if (!list.any((known) => known.id == t.id)) list.add(t);
  }

  @override
  Future<Set<String>> offlineCopies() async => {};
}

class Maps implements MapRepository {
  @override
  Future<List<Region>> catalog() async => [];
  @override
  Future<List<LocalMap>> installed() async => [];
  @override
  Future<String?> composeStyle(List<LocalMap> maps) async => null;
  @override
  Future<void> download(Region r, void Function(double) progress) async {}
  @override
  Future<void> remove(String id) async {}
}

class Gps implements PositionSource {
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => const Stream.empty();
}

class Elevation implements ElevationSource {
  @override
  Future<Trail> complete(Trail t) async => t;
}

class Sync implements Synchronizer {
  @override
  Future<String> synchronize() async => 'ok';
  @override
  Future<void> resolveConflicts() async {}
}

AppController controller() => AppController(
  library: Library(Repository(), XmlGpxDecoder(), Elevation()),
  maps: Maps(),
  gps: Gps(),
  sync: Sync(),
  setAwake: (_) async {},
  vibrate: () async {},
);
void main() {
  test(
    'browsing another GPX preserves the active navigation session',
    () async {
      final app = controller();
      Trail trail(String id) => Trail(
        id: id,
        name: id,
        segments: [
          [const GeoPoint(0, 0), const GeoPoint(0, .02)],
        ],
        pois: [],
      );
      final a = trail('a'), b = trail('b');
      app.select(a);
      await app.start();
      final tracking = app.session;
      app.focus(b);
      expect(app.focused!.id, 'b');
      expect(app.selected!.id, 'a');
      expect(app.session, same(tracking));
      expect(app.session!.active, true);
      app.dispose();
    },
  );
  test('interactive days continue at the last arrival and edits replace only the selected day', () async {
    final app = controller();
    final trail = Trail(
      id: 'a',
      name: 'a',
      segments: [
        [const GeoPoint(0, 0), const GeoPoint(0, .02)],
      ],
      pois: [],
    );
    app.trails = [trail];
    app.beginPlanning(trail);
    app.placeBoundary(100);
    app.placeBoundary(500);
    await app.saveDay();
    expect(app.days, hasLength(1));
    expect(app.draftStart, 500);
    expect(app.pickingStart, false);
    app.placeBoundary(800);
    await app.saveDay();
    app.editDay(0);
    app.placeBoundary(150);
    app.placeBoundary(600);
    await app.saveDay();
    expect(app.days.map((d) => [d.start, d.end]), [
      [150, 600],
      [500, 800],
    ]);
    app.dispose();
  });
  test('shutdown drains the first action even when another action is ignored as busy', () async {
    final app = controller();
    final pending = Completer<void>();
    final first = app.run(() => pending.future);
    await app.run(() async {
      fail('busy action must not run');
    });
    var closed = false;
    final closing = app.shutdown().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, false);
    pending.complete();
    await first;
    await closing;
    expect(closed, true);
    app.dispose();
  });

  test(
    'inactive/hidden/paused sequence retains resume intent until fresh GPS',
    () async {
      final app = controller();
      app.select(
        Trail(
          id: '1',
          name: 'test',
          segments: [
            [const GeoPoint(0, 0), const GeoPoint(0, .01)],
          ],
          pois: [],
        ),
      );
      await app.start();
      expect(app.session!.active, true);
      app.lifecycle(false);
      app.lifecycle(false);
      app.lifecycle(false);
      expect(app.session!.active, false);
      app.lifecycle(true);
      await Future<void>.delayed(Duration.zero);
      expect(app.session!.active, true);
      expect(app.session!.projection, isNull);
      app.dispose();
    },
  );
  testWidgets('empty library is honest and usable on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = controller();
    await tester.pumpWidget(
      GpixApp(app, mapBuilder: (_) => const ColoredBox(color: Colors.green)),
    );
    await tester.pumpAndSettle();
    expect(find.text("Import a trail"), findsOneWidget);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My trails'));
    await tester.pumpAndSettle();
    expect(find.text('0 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
