import 'dart:async';
import 'dart:math' as math;

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
import 'package:gpix/presentation/finish_route_dialog.dart';
import 'package:gpix/presentation/localization.dart';
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

  test('a finished free walk becomes a route named and described by the '
      'walker; the walk in history takes that name', () async {
    final gps = _Gps();
    final repository = Repository();
    var ids = 0;
    final app = AppController(
      library: Library(repository, XmlGpxDecoder(), Elevation()),
      maps: Maps(),
      gps: Gps(),
      sync: Sync(),
      setAwake: (_) async {},
      vibrate: () async {},
      recorder: RecordWalk(
        _MemoryRecording(),
        repository,
        gps,
        () => 'id-${ids++}',
        routeName: (_) => 'Route of the day',
      ),
    );
    await app.freeWalk();
    // About 85 m walked north, one fix per second.
    final start = DateTime.now().subtract(const Duration(seconds: 14));
    for (var i = 0; i < 16; i++) {
      gps.positions.add(
        Fix(GeoPoint(43 + i * .00005, 3), 5, start.add(Duration(seconds: i))),
      );
      await Future<void>.delayed(Duration.zero);
    }
    await app.finishWalk(
      name: 'Boucle des crêtes 🌲',
      description: 'Par le bois de Connigis',
    );
    final route = app.trails.single;
    expect(route.name, 'Boucle des crêtes 🌲');
    expect(route.description, 'Par le bois de Connigis');
    final walk = app.history.single;
    expect(walk.name, 'Boucle des crêtes 🌲');
    expect(walk.walk!.routeId, route.id);
    expect(app.recorder!.current, isNull);
    app.dispose();
  });

  for (final language in ['en', 'fr']) {
    testWidgets('finishing a route asks for its name and an optional '
        'description ($language)', (tester) async {
      final l10n = lookupAppLocalizations(Locale(language));
      RouteDetails? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showDialog<RouteDetails>(
                  context: context,
                  builder: (_) =>
                      const FinishRouteDialog(suggestedName: 'Suggested'),
                ),
                child: const Text('finish'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.finishRouteQuestion), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text(l10n.routeDescriptionOptional), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '   ');
      await tester.tap(find.text(l10n.saveWalk));
      await tester.pumpAndSettle();
      expect(find.text(l10n.enterName), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(fields.first, ' Tour du Grand Bois ');
      await tester.enterText(fields.last, 'Boue après la pluie');
      await tester.tap(find.text(l10n.saveWalk));
      await tester.pumpAndSettle();
      expect(result?.name, 'Tour du Grand Bois');
      expect(result?.description, 'Boue après la pluie');

      // Continuing the walk closes the dialog without finishing.
      result = null;
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.continueAction));
      await tester.pumpAndSettle();
      expect(find.byType(FinishRouteDialog), findsNothing);
      expect(result, isNull);
    });
  }

  group('direction arrow polygons', () {
    const position = GeoPoint(49.03, 3.54);
    // Clockwise from north; flat approximation, exact enough over metres.
    double bearingBetween(GeoPoint a, GeoPoint b) {
      final east = (b.lon - a.lon) * math.cos(a.lat * math.pi / 180);
      final north = b.lat - a.lat;
      return (math.atan2(east, north) * 180 / math.pi + 360) % 360;
    }

    List<GeoPoint> ring(Map<String, dynamic> feature) => [
      for (final c in (feature['geometry']['coordinates'] as List).first)
        GeoPoint((c as List)[1] as double, c[0] as double),
    ];
    Map<String, dynamic> part(List<Map<String, dynamic>> all, String name) =>
        all.lastWhere((f) => f['properties']['part'] == name);

    test(
      'the chevron points along the bearing and centres on the position',
      () {
        for (final bearing in [0.0, 90.0, 225.0]) {
          final arrow = ring(
            part(positionArrowFeatures(position, bearing, 1), 'arrow'),
          );
          final tip = arrow.first;
          // 12 logical pixels ahead at one metre per pixel.
          expect(distance(position, tip), closeTo(12, .01));
          expect(bearingBetween(position, tip), closeTo(bearing % 360, .5));
          // The notch lies behind the position, the wings beside it.
          expect(distance(position, arrow[2]), closeTo(5, .01));
          expect(
            bearingBetween(position, arrow[2]),
            closeTo((bearing + 180) % 360, .5),
          );
        }
      },
    );

    test('the beam fans out ahead of the walker only', () {
      final beams = positionArrowFeatures(
        position,
        0,
        1,
      ).where((f) => f['properties']['part'] == 'beam').toList();
      expect(beams, hasLength(3));
      for (final beam in beams) {
        for (final p in ring(beam).skip(1).take(13)) {
          expect(p.lat, greaterThan(position.lat), reason: 'ahead (north)');
        }
      }
    });

    test('the arrow keeps its screen size at every zoom', () {
      double tip(double zoom) => distance(
        position,
        ring(
          part(
            positionArrowFeatures(
              position,
              0,
              metresPerPixel(zoom, position.lat),
            ),
            'arrow',
          ),
        ).first,
      );
      expect(tip(15) / tip(16), closeTo(2, .001));
      // Zoom 16 at this latitude: about 0.78 m per logical pixel.
      expect(metresPerPixel(16, position.lat), closeTo(.782, .01));
    });
  });
}
