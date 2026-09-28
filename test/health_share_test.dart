import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/data/health_connect.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/recording_store.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/app_message.dart';
import 'package:gpix/domain/health_data.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/walk_energy.dart';
import 'package:gpix/domain/walk_recording.dart';

import 'guidance_test.dart' show at;
import 'lifecycle_test.dart' show Maps, Elevation, Sync;

class FakeHealth implements HealthDataSource {
  double? weight;
  HealthAvailability sharing = HealthAvailability.connected;
  HealthAvailability afterRequest = HealthAvailability.connected;
  bool failShare = false;
  var requests = 0;
  final shared = <HealthExport>[];
  @override
  Future<double?> latestWeight() async => weight;
  @override
  Future<HealthAvailability> sharingStatus() async => sharing;
  @override
  Future<HealthAvailability> authorizeSharing() async {
    requests++;
    return sharing = afterRequest;
  }

  @override
  Future<void> share(HealthExport export) async {
    if (failShare) throw PlatformException(code: 'health');
    shared.add(export);
  }

  @override
  Future<HealthAvailability> status() async => HealthAvailability.connected;
  @override
  Future<HealthAvailability> authorize() async => HealthAvailability.connected;
  @override
  Future<HealthSummary> read(DateTime start, DateTime end) async =>
      HealthSummary(readAt: end, sources: const []);
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> openZepp() async {}
}

class _Gps implements PositionSource {
  final events = StreamController<Fix>.broadcast();
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => events.stream;
}

class _Profiles implements ProfileStore {
  WalkerProfile profile = const WalkerProfile();
  @override
  Future<({WalkerProfile profile, bool pending})> read() async =>
      (profile: profile, pending: false);
  @override
  Future<void> save(WalkerProfile value, {required bool pending}) async =>
      profile = value;
}

final started = DateTime.utc(2026, 9, 28, 8);
Trail finished({HealthSummary? health, double climb = 0}) => Trail(
  id: 'walk-1',
  name: 'Tour du lac',
  segments: [
    [GeoPoint(0, 0, 100), GeoPoint(at(1000, 0).lat, 0, 100 + climb)],
  ],
  pois: [],
  walk: WalkDetails(
    started: started,
    ended: started.add(const Duration(minutes: 15)),
    seconds: 900,
    steps: 1300,
    estimatedCalories: 44.5,
    health: health,
    samples: [
      WalkSample(started.subtract(const Duration(seconds: 1)), at(0, 0), 5, 0),
      WalkSample(started, GeoPoint(0, 0, 100), 5, 0),
      WalkSample(
        started.add(const Duration(minutes: 14)),
        GeoPoint(at(1000, 0).lat, 0, 100 + climb),
        4,
        0,
      ),
    ],
  ),
);

void main() {
  test('export carries the walk, its route and only phone-made measures', () {
    final export = HealthExport.of(finished())!;
    expect(export.walkId, 'walk-1');
    expect(export.title, 'Tour du lac');
    expect(export.metres, closeTo(1000, 1));
    expect(export.steps, 1300);
    expect(export.activeCalories, 44.5);
    expect(export.route, hasLength(2), reason: 'within the session only');
    expect(export.hiking, isFalse);
    expect(HealthExport.of(finished(climb: 150))!.hiking, isTrue);
    final fromWatch = HealthExport.of(
      finished(
        health: HealthSummary(
          readAt: started,
          sources: const ['watch'],
          steps: 1400,
          activeCalories: 50,
        ),
      ),
    )!;
    expect(fromWatch.steps, isNull, reason: 'never written back');
    expect(fromWatch.activeCalories, isNull);
    final running = Trail(
      id: 'r',
      name: 'R',
      segments: [],
      pois: [],
      walk: WalkDetails(started: started, seconds: 0),
    );
    expect(HealthExport.of(running), isNull);
  });

  test('the Android adapter sends every exported field', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Map<Object?, Object?>? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidHealthConnect.channel, (call) async {
          if (call.method == 'share') sent = call.arguments as Map;
          if (call.method == 'weight') return 71.3;
          return null;
        });
    const adapter = AndroidHealthConnect();
    expect(await adapter.latestWeight(), 71.3);
    await adapter.share(HealthExport.of(finished())!);
    expect(sent!['id'], 'walk-1');
    expect(sent!['start'], '2026-09-28T08:00:00.000Z');
    expect(sent!['steps'], 1300);
    expect(sent!['activeCalories'], 44.5);
    expect((sent!['route'] as List).first, [
      '2026-09-28T08:00:00.000Z',
      0.0,
      0.0,
      5.0,
      100.0,
    ]);
  });

  group('controller', () {
    late Database db;
    late _Gps gps;
    late FakeHealth health;
    late _Profiles profiles;
    late AppController app;
    late RecordWalk recorder;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await openLocalDatabase(inMemoryDatabasePath);
      gps = _Gps();
      health = FakeHealth();
      profiles = _Profiles();
      final repository = SqliteTrailRepository(db);
      recorder = RecordWalk(
        SqliteRecordingStore(db),
        repository,
        gps,
        () => 'walk-${DateTime.now().microsecondsSinceEpoch}',
      );
      app = AppController(
        library: Library(repository, XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: gps,
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
        recorder: recorder,
        health: health,
        profiles: profiles,
      );
    });
    tearDown(() async {
      await app.shutdown();
      await gps.events.close();
      await db.close();
    });

    test('Health Connect weight is used only while none is entered', () async {
      health.weight = 71.3;
      await app.initialize();
      await pumpEventQueue();
      expect(app.massKg, 71.3);
      expect(recorder.massKg, 71.3);
      await app.saveProfile(const WalkerProfile(packKg: 7));
      expect(app.massKg, closeTo(78.3, 1e-9));
      await app.saveProfile(const WalkerProfile(weightKg: 68, packKg: 7));
      expect(app.massKg, 75, reason: 'own weight wins');
      health.weight = 3; // implausible values are ignored
      await app.saveProfile(const WalkerProfile());
      await app.refreshHealthWeight();
      expect(app.massKg, isNull);
    });

    test('a finished walk is shared automatically when enabled', () async {
      await app.initialize();
      await app.setShareWithHealth(true);
      expect(app.shareWithHealth, isTrue);
      await app.freeWalk();
      await app.finishWalk();
      expect(health.shared, hasLength(1));
      expect(health.shared.single.title, isNotEmpty);
    });

    test('a failed export keeps the walk and says so', () async {
      await app.initialize();
      await app.setShareWithHealth(true);
      health.failShare = true;
      await app.freeWalk();
      await app.finishWalk();
      expect(app.history, hasLength(1));
      expect(app.message, AppMessage.healthShareFailed);
    });

    test('sending asks for permission; refusal keeps sharing off', () async {
      await app.initialize();
      health
        ..sharing = HealthAvailability.needsPermission
        ..afterRequest = HealthAvailability.needsPermission;
      await app.setShareWithHealth(true);
      expect(app.shareWithHealth, isFalse);
      expect(app.message, AppMessage.healthSharePermission);
      await app.shareToHealth(finished());
      expect(health.requests, 2);
      expect(health.shared, isEmpty);
      expect(
        app.message,
        isA<MessageFailure>().having(
          (e) => e.detail,
          'detail',
          AppMessage.healthSharePermission,
        ),
      );
      health.afterRequest = HealthAvailability.connected;
      await app.shareToHealth(finished());
      expect(health.shared.single.walkId, 'walk-1');
      expect(app.message, AppMessage.healthShared);
    });
  });
}
