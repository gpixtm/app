import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:gpix/presentation/app.dart';
import 'package:gpix/presentation/position_arrow.dart';

import 'lifecycle_test.dart' show Repository, Maps, Gps, Elevation, Sync;

class _MemoryRecording implements RecordingStore {
  Trail? saved;
  @override
  Future<Trail?> read() async => saved;
  @override
  Future<void> write(Trail recording) async => saved = recording;
  @override
  Future<void> clear() async => saved = null;
}

/// Positions stay open, like a real GPS, so pausing cancels a live stream.
class _Gps implements PositionSource {
  final positions = StreamController<Fix>.broadcast();
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => positions.stream;
}

AppController _recordingController() {
  final repository = Repository();
  return AppController(
    library: Library(repository, XmlGpxDecoder(), Elevation()),
    maps: Maps(),
    gps: Gps(),
    sync: Sync(),
    setAwake: (_) async {},
    vibrate: () async {},
    recorder: RecordWalk(_MemoryRecording(), repository, _Gps(), () => 'walk'),
  );
}

/// A walk recorded while a GPX trail is shown on the map.
Future<AppController> _walkBesideTrail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = _recordingController();
  await app.library.repository.save(
    Trail(
      id: 'gr',
      name: 'Sentier des crêtes',
      segments: const [
        [GeoPoint(43, 3), GeoPoint(43.01, 3.01)],
      ],
      pois: const [],
    ),
  );
  await app.reload();
  app.focus(app.trails.single);
  await app.freeWalk();
  return app;
}

Finder _inPanel(String text) => find.descendant(
  of: find.byKey(const ValueKey('navigation')),
  matching: find.text(text),
);

void main() {
  testWidgets('a walk recorded beside a GPX is paused from the collapsed '
      'bottom panel', (tester) async {
    final app = await _walkBesideTrail(tester);
    await tester.pumpWidget(
      GpixApp(app, mapBuilder: (_) => const ColoredBox(color: Colors.green)),
    );
    await tester.pumpAndSettle();
    expect(_inPanel('● Recording in progress'), findsOneWidget);
    expect(_inPanel('Pause'), findsOneWidget);
    expect(_inPanel('Finish the route'), findsOneWidget);
    expect(find.text('Pause, finish and history'), findsNothing);
    // Visible without expanding the panel.
    expect(
      tester.getBottomLeft(_inPanel('Pause')).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    await tester.tap(_inPanel('Pause'));
    await tester.pump();
    expect(app.recorder!.active, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a paused walk resumes from the bottom panel; history only '
      'points back to the map', (tester) async {
    // Cancelling the GPS subscription completes on the real event loop, so
    // the walk is started and paused there.
    final app = (await tester.runAsync(() async {
      final app = await _walkBesideTrail(tester);
      await app.pauseWalk();
      return app;
    }))!;
    await tester.pumpWidget(
      GpixApp(app, mapBuilder: (_) => const ColoredBox(color: Colors.green)),
    );
    await tester.pumpAndSettle();
    expect(_inPanel('Walk paused · ready to resume'), findsOneWidget);
    expect(_inPanel('Resume'), findsOneWidget);
    expect(_inPanel('Finish the route'), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(find.text('Walk paused · ready to resume'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Finish'), findsNothing);
    expect(find.text('Finish the route'), findsNothing);
    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();
    expect(_inPanel('Resume'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  test('the direction arrow image is centred on the position', () async {
    final bytes = await positionArrowPng(2);
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, (positionArrowSide * 2).round());
    expect(image.height, (positionArrowSide * 2).round());
    final pixels = (await image.toByteData())!;
    int alpha(int x, int y) => pixels.getUint8((y * image.width + x) * 4 + 3);
    final c = image.width ~/ 2;
    expect(alpha(c, c), 255, reason: 'the arrow covers the position');
    expect(alpha(0, 0), 0, reason: 'corners stay transparent');
    // The beam lies ahead (north) of the arrow, never behind it.
    expect(alpha(c, c - 40), greaterThan(0));
    expect(alpha(c, c + 40), 0);
    image.dispose();
  });
}
