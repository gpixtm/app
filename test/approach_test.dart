import 'package:gpix/presentation/localization.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/data/approach_source.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/server_connection.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/approach.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/trail_geometry.dart';
import 'package:gpix/presentation/join_departure.dart';

import 'auth_session_test.dart' show MemoryCredentials, environment;
import 'lifecycle_test.dart' as fixtures;

Map<String, dynamic> response() => jsonDecode(
  File('test/fixtures/approach-reims.json')
      .readAsStringSync()
      .replaceFirst('\ufeff', ''),
);
Trail target() => Trail(
  id: 'test-target',
  name: 'Reims',
  segments: [
    [const GeoPoint(49.256, 4.034), const GeoPoint(49.26, 4.04)],
  ],
  pois: [],
);

class Server extends ServerConnection {
  Server()
    : super(
        http.Client(),
        environment: environment,
        credentials: MemoryCredentials(),
      );
  bool offline = false;
  Object? sent;
  @override
  Future<dynamic> request(String path, {Object? body}) async {
    expect(path, '/api/approach');
    sent = body;
    if (offline) throw const SocketException('offline');
    return response();
  }
}

class Source implements ApproachSource {
  bool fail = false;
  GeoPoint? destination;
  @override
  Future<ApproachRoute> calculate(
    GeoPoint origin,
    Trail target,
    GeoPoint destination,
  ) async {
    this.destination = destination;
    if (fail) throw StateError('offline');
    return decodeApproach(response(), target);
  }
}

AppController appWith(Source source) => AppController(
  library: Library(
    fixtures.Repository(),
    XmlGpxDecoder(),
    fixtures.Elevation(),
  ),
  maps: fixtures.Maps(),
  gps: fixtures.Gps(),
  sync: fixtures.Sync(),
  setAwake: (_) async {},
  vibrate: () async {},
  approachSource: source,
);

void main() {
  test('nearest connection uses the segment interior, never the GPX start or an artificial gap', () async {
    final trail = Trail(
      id: 'long',
      name: 'Long GPX',
      segments: [
        [const GeoPoint(0, 0), const GeoPoint(0, 1)],
        [const GeoPoint(1, 1), const GeoPoint(1, 2)],
      ],
      pois: [],
    );
    const origin = GeoPoint(.001, .8);
    final point = nearestConnection(trail, origin)!;
    expect(point.lat, 0);
    expect(point.lon, closeTo(.8, .000001));
    expect(distance(point, trail.points.first), greaterThan(80000));
    final gap = nearestConnection(trail, const GeoPoint(.5, 1))!;
    expect(gap.lat == 0 || gap.lat == 1, true);
    final source = Source();
    final app = appWith(source);
    addTearDown(app.dispose);
    app.mapFix = Fix(origin, 5, DateTime.now());
    app.select(trail);
    app.session!.reverse = true;
    await app.joinTrail(trail);
    expect(source.destination!.lon, closeTo(.8, .000001));
    expect(app.approachReverse, true);
    final external = await app.closestJoinPoint(trail);
    expect(external!.lon, source.destination!.lon);
    app.mapFix = Fix(const GeoPoint(.001, .9), 5, DateTime.now());
    await app.joinTrail(trail);
    expect(source.destination!.lon, closeTo(.9, .000001));
  });
  test('real French pedestrian response decodes polyline6, turns and arrival only with precise GPS', () {
    final route = decodeApproach(response(), target());
    final geometry = TrailGeometry(route.trail);
    expect(geometry.total, closeTo(479, 10));
    expect(route.steps.length, 7);
    expect(
      route.next(route.steps[2].along - 20)!.instruction,
      contains('gauche'),
    );
    final s = TrackingSession(geometry)..resume();
    final now = DateTime.now();
    s.accept(Fix(target().points.first, 5, now), now);
    expect(route.arrived(s, target().points.first, now), true);
    expect(
      route.arrived(
        s,
        target().points.first,
        now.add(const Duration(minutes: 1)),
      ),
      false,
    );
    s.accept(
      Fix(target().points.first, 40, now.add(const Duration(seconds: 1))),
      now.add(const Duration(seconds: 1)),
    );
    expect(route.arrived(s, target().points.first, now), false);
    expect(
      () => decodeApproach({...response(), 'shape': '_'}, target()),
      throwsFormatException,
    );
    expect(
      () => decodeApproach({
        ...response(),
        'steps': [
          {'index': 999999, 'instruction': 'test'},
        ],
      }, target()),
      throwsFormatException,
    );
  });
  test('account SQLite retains route for nearby offline reuse but rejects a distant origin', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openLocalDatabase(inMemoryDatabasePath);
    final server = Server();
    addTearDown(() async {
      server.client.close();
      await db.close();
    });
    final source = ApiApproachSource(server, db);
    final online = await source.calculate(
      const GeoPoint(49.254, 4.03),
      target(),
      target().points.first,
    );
    expect(online.cached, false);
    expect((server.sent as Map)['destination'], [49.256, 4.034]);
    server.offline = true;
    final cached = await ApiApproachSource(server, db).calculate(
      online.trail.points.elementAt(10),
      target(),
      target().points.first,
    );
    expect(cached.cached, true);
    await expectLater(
      source.calculate(const GeoPoint(48, 3), target(), target().points.first),
      throwsStateError,
    );
    await expectLater(
      source.calculate(
        const GeoPoint(49.254, 4.03),
        target(),
        target().points.last,
      ),
      throwsStateError,
    );
  });
  test(
    'offline guidance isolates languages and preserves legacy French routes',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openLocalDatabase(inMemoryDatabasePath);
      final server = Server();
      addTearDown(() async {
        server.client.close();
        await db.close();
      });
      final french = ApiApproachSource(server, db, languageCode: () => 'fr');
      final route = await french.calculate(
        const GeoPoint(49.254, 4.03),
        target(),
        target().points.first,
      );
      expect((server.sent as Map)['language'], 'fr');
      final saved = (await db.query(
        'settings',
        where: 'key=?',
        whereArgs: ['approach-nearest:fr:${target().id}'],
      )).single;
      await db.delete('settings', where: 'key=?', whereArgs: [saved['key']]);
      await db.insert('settings', {
        'key': 'approach-nearest:${target().id}',
        'value': saved['value'],
      });
      server.offline = true;
      final origin = route.trail.points.elementAt(10);
      expect(
        (await french.calculate(
          origin,
          target(),
          target().points.first,
        )).cached,
        true,
      );
      await expectLater(
        ApiApproachSource(
          server,
          db,
          languageCode: () => 'en',
        ).calculate(origin, target(), target().points.first),
        throwsStateError,
      );
    },
  );
  test('approach stays separate from saved GPX; failures preserve active guidance; start GPX restores reverse', () async {
    final source = Source();
    final app = appWith(source);
    addTearDown(app.dispose);
    app.select(target());
    app.session!.reverse = true;
    app.mapFix = Fix(const GeoPoint(49.254, 4.03), 5, DateTime.now());
    await app.joinTrail(target());
    expect(source.destination!.lat, closeTo(49.256, .00001));
    expect(app.approachDestination!.lat, source.destination!.lat);
    expect(app.approach, isNotNull);
    expect(app.session!.active, true);
    expect(app.session!.geometry.total, closeTo(479, 10));
    expect((await app.library.repository.all()), isEmpty);
    final old = app.session;
    source.fail = true;
    await app.joinTrail(target());
    expect(identical(app.session, old), true);
    expect(app.session!.active, true);
    await app.startOriginalTrail();
    expect(app.approach, isNull);
    expect(app.session!.reverse, true);
    expect(app.session!.active, true);
    expect(app.selected!.id, target().id);
  });
  testWidgets(
    'join sheet offers internal walking and external fallback without starting until choice',
    (tester) async {
      final app = appWith(Source());
      addTearDown(app.dispose);
      await tester.pumpWidget(
        LocalizedApp(
          homeBuilder: (context) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showJoinTrail(context, app, target()),
                child: const Text('Join'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(find.text("Walk with Gpix"), findsOneWidget);
      expect(find.text("Drive with Google Maps"), findsOneWidget);
      expect(app.approach, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
