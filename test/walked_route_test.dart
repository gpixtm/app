import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/trail_identity_hash.dart';
import 'package:gpix/data/recording_store.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/app_message.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:gpix/domain/walked_route.dart';

import 'lifecycle_test.dart' show Maps, Elevation, Sync;

class _Gps implements PositionSource {
  final events = StreamController<Fix>.broadcast();
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => events.stream;
}

/// About 9.5 m of longitude at latitude 49.
const step = .00013;

Trail line(String id, List<List<GeoPoint>> segments, {WalkDetails? walk}) =>
    Trail(id: id, name: id, segments: segments, pois: [], walk: walk);

Trail walked(List<List<GeoPoint>> segments) => line(
  'walk',
  segments,
  walk: WalkDetails(started: DateTime(2026, 9, 28), seconds: 600),
);

List<GeoPoint> straight(int count, {double lat = 49, double wobble = 0}) => [
  for (var i = 0; i < count; i++)
    GeoPoint(lat + (i.isOdd ? wobble : -wobble), 4 + i * step),
];

void main() {
  final existing = line('known', [
    [const GeoPoint(49, 4), const GeoPoint(49, 4 + 40 * step)],
  ]);

  test('a walk that stays on an existing route, between vertices and with '
      'GPS noise, creates no duplicate', () {
    // 0.0001° of latitude is about 11 m, well within GPS tolerance.
    final result = routeFromWalk(
      walked([straight(30, wobble: .0001)]),
      [existing],
      id: 'new',
      name: 'Route',
    );
    expect(result.outcome, WalkedRouteOutcome.alreadyKnown);
    expect(result.trail!.id, 'known');
  });

  test('any detour beyond tolerance makes a new route', () {
    final points = straight(30);
    points[15] = GeoPoint(49.0006, points[15].lon); // about 67 m aside
    final result = routeFromWalk(
      walked([points]),
      [existing],
      id: 'new',
      name: 'Route of 28 Sep',
    );
    expect(result.outcome, WalkedRouteOutcome.created);
    expect(result.trail!.id, 'new');
    expect(result.trail!.name, 'Route of 28 Sep');
    expect(result.trail!.walk, isNull);
    expect(result.trail!.followable, true);
  });

  test('a walk extending past the end of a route is a new route', () {
    final result = routeFromWalk(
      walked([straight(50)]),
      [existing],
      id: 'new',
      name: 'Route',
    );
    expect(result.outcome, WalkedRouteOutcome.created);
  });

  test('recorded pauses stay separate segments and single points are '
      'dropped', () {
    final first = straight(10);
    final second = straight(10, lat: 49.01);
    final result = routeFromWalk(
      walked([
        first,
        [const GeoPoint(49.005, 4)],
        second,
      ]),
      const [],
      id: 'new',
      name: 'Route',
    );
    expect(result.outcome, WalkedRouteOutcome.created);
    expect(result.trail!.segments, hasLength(2));
    expect(result.trail!.segments.first, hasLength(10));
  });

  test('previous walks in history never count as existing routes', () {
    final history = line('history', existing.segments, walk: walked([]).walk);
    final result = routeFromWalk(
      walked([straight(30)]),
      [history],
      id: 'new',
      name: 'Route',
    );
    expect(result.outcome, WalkedRouteOutcome.created);
  });

  test('a walk shorter than 50 m does not become a route', () {
    final result = routeFromWalk(
      walked([straight(4)]),
      const [],
      id: 'new',
      name: 'Route',
    );
    expect(result.outcome, WalkedRouteOutcome.tooShort);
    expect(result.trail, isNull);
  });

  group('recorded on this phone', () {
    late Directory directory;
    late Database db;
    late _Gps gps;
    var ids = 0;
    RecordWalk recorder() => RecordWalk(
      SqliteRecordingStore(db),
      SqliteTrailRepository(db),
      gps,
      () => 'id-${ids++}',
      routeName: (started) => 'Route ${started.year}',
    );

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp('gpix-route');
      db = await openLocalDatabase('${directory.path}/route.sqlite');
      gps = _Gps();
    });
    tearDown(() async {
      await gps.events.close();
      await db.close();
      await directory.delete(recursive: true);
    });

    Future<void> walk(RecordWalk service, List<GeoPoint> points) async {
      final now = DateTime.now();
      for (var i = 0; i < points.length; i++) {
        final time = now.subtract(Duration(seconds: points.length - i));
        gps.events.add(Fix(points[i], 5, time));
      }
      await Future<void>.delayed(Duration.zero);
    }

    Future<List<Trail>> routes() async => (await SqliteTrailRepository(
      db,
    ).all()).where((t) => t.walk == null).toList();

    test('a free walk becomes one synced route; walking it again does not '
        'duplicate it', () async {
      final service = recorder();
      await service.initialize();
      await service.start();
      await walk(service, straight(14));
      final created = await service.keepRoute(await routes());
      expect(created!.outcome, WalkedRouteOutcome.created);
      expect(created.trail!.name, 'Route ${DateTime.now().year}');
      final history = await service.finish();
      expect(history!.walk!.ended, isNotNull);
      expect(await routes(), hasLength(1));
      expect(
        (await SqliteTrailRepository(db).all()).where((t) => t.walk != null),
        hasLength(1),
      );

      await service.start();
      await walk(service, straight(14, wobble: .00008));
      final again = await service.keepRoute(await routes());
      expect(again!.outcome, WalkedRouteOutcome.alreadyKnown);
      expect(again.trail!.id, created.trail!.id);
      await service.finish();
      expect(await routes(), hasLength(1));
      await service.close();
    });

    test('a new route takes the shared identifier of its line', () async {
      final service = RecordWalk(
        SqliteRecordingStore(db),
        SqliteTrailRepository(db),
        gps,
        () => 'random',
        identity: const HashedTrailIdentity(),
      );
      await service.initialize();
      await service.start();
      await walk(service, straight(14));
      final created = await service.keepRoute(await routes());
      const identity = HashedTrailIdentity();
      expect(
        created!.trail!.id,
        identity.sharedId(identity.fingerprint(created.trail!.segments)!),
      );
      await service.finish(routeId: created.trail!.id);
      await service.close();
    });

    test('an interrupted finish retried later does not duplicate the '
        'route', () async {
      final service = recorder();
      await service.initialize();
      await service.start();
      await walk(service, straight(14));
      await service.keepRoute(await routes());
      // The process stops before the walk reaches history.
      await service.close();
      final restarted = recorder();
      await restarted.initialize();
      final retry = await restarted.keepRoute(await routes());
      expect(retry!.outcome, WalkedRouteOutcome.alreadyKnown);
      await restarted.finish();
      expect(await routes(), hasLength(1));
      await restarted.close();
    });

    test('a walk guided by a GPX never creates a route', () async {
      final service = recorder();
      await service.initialize();
      await service.start(source: existing);
      await walk(service, straight(14, lat: 49.1));
      expect(await service.keepRoute(await routes()), isNull);
      await service.finish();
      expect(await routes(), isEmpty);
      await service.close();
    });

    test('finishing a free walk shows the new route on the map and keeps '
        'the walk in history', () async {
      final repository = SqliteTrailRepository(db);
      final service = recorder();
      final app = AppController(
        library: Library(repository, XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: gps,
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
        recorder: service,
      );
      await app.initialize();
      await app.freeWalk();
      expect(service.active, true);
      await walk(service, straight(14));
      await app.finishWalk();
      expect(app.trails, hasLength(1));
      expect(app.history, hasLength(1));
      expect(app.focused!.id, app.trails.single.id);
      // The walk counts in the new route's statistics from now on.
      expect(app.history.single.walk!.routeId, app.trails.single.id);
      expect(app.history.single.walk!.sourceTrailId, isNull);
      expect(
        app.message,
        isA<AppMessage>().having((m) => m.code, 'code', 'routeCreated'),
      );
      expect(service.current, isNull);
      await app.shutdown();
    });
  });
}
