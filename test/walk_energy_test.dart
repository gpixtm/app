import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/recording_store.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/health_data.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/sync.dart';
import 'package:gpix/domain/walk_energy.dart';
import 'package:gpix/domain/walk_recap.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:gpix/l10n/generated/app_localizations.dart';
import 'package:gpix/presentation/guidance_text.dart';

import 'guidance_test.dart' show at;

/// One sample every 10 m at [kmh], climbing [grade] (rise/run).
List<WalkSample> track({
  required double metres,
  double kmh = 5,
  double grade = 0,
  double Function(int)? noise,
  bool altitude = true,
}) {
  final step = Duration(milliseconds: (10 / (kmh / 3.6) * 1000).round());
  final start = DateTime(2026, 9, 28, 8);
  return [
    for (var i = 0; i * 10 <= metres; i++)
      WalkSample(
        start.add(step * i),
        GeoPoint(
          at(i * 10.0, 0).lat,
          0,
          altitude ? 100 + grade * i * 10 + (noise?.call(i) ?? 0) : null,
        ),
        5,
        0,
      ),
  ];
}

class FakeSteps implements StepCounter {
  FakeSteps({this.allowed = true});
  final bool allowed;
  int? counter;
  var started = 0, stopped = 0;
  @override
  Future<bool> start() async {
    started++;
    return allowed;
  }

  @override
  Future<int?> read() async => counter;
  @override
  Future<void> stop() async => stopped++;
}

class _Gps implements PositionSource {
  final events = StreamController<Fix>.broadcast();
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => events.stream;
}

class MemoryProfiles implements ProfileStore {
  WalkerProfile profile = const WalkerProfile();
  bool pending = false;
  @override
  Future<({WalkerProfile profile, bool pending})> read() async =>
      (profile: profile, pending: pending);
  @override
  Future<void> save(WalkerProfile value, {required bool pending}) async {
    profile = value;
    this.pending = pending;
  }
}

class FakeProfileTransport implements ProfileTransport {
  WalkerProfile remote = const WalkerProfile(weightKg: 80);
  final sent = <WalkerProfile>[];
  void Function()? duringSend;
  @override
  Future<WalkerProfile> fetch() async => remote;
  @override
  Future<void> send(WalkerProfile profile) async {
    sent.add(profile);
    duringSend?.call();
    remote = profile;
  }
}

class _NoSync implements SyncStore, SyncTransport {
  @override
  Future<SyncOperation?> next() async => null;
  @override
  Future<void> acknowledge(
    SyncOperation op,
    int revision, {
    String? publicId,
  }) async {}
  @override
  Future<void> conflict(SyncOperation op) async {}
  @override
  Future<void> merge(List<SyncOperation> remote) async {}
  @override
  Future<int> conflictsCount() async => 0;
  @override
  Future<void> preserveConflicts(List<SyncOperation> remote) async {}
  @override
  Future<SyncResult> push(SyncOperation operation) async =>
      const SyncResult(1, false);
  @override
  Future<List<SyncOperation>> pull() async => [];
}

void main() {
  group('active calories', () {
    test('level walking matches the ACSM equation', () {
      // 70 kg, 5 km/h for one hour: 0.1·83.3 ml/kg/min · 70 kg · 60 min · 5 kcal/L.
      final kcal = activeCalories(track(metres: 5000), 70)!;
      expect(kcal, closeTo(175, 3));
      expect(
        activeCalories(track(metres: 5000), 85)!,
        closeTo(175 * 85 / 70, 4),
      );
    });

    test('slopes cost more uphill and less downhill, never below zero', () {
      final level = activeCalories(track(metres: 2000), 70)!;
      final up = activeCalories(track(metres: 2000, grade: .1), 70)!;
      final down = activeCalories(track(metres: 2000, grade: -.1), 70)!;
      // ACSM: 10 % adds 1.8·0.1 / 0.1 = 180 % of the level cost.
      expect(up / level, closeTo(2.8, .1));
      expect(down, lessThan(level));
      expect(down, greaterThan(0));
    });

    test('GPS altitude noise barely changes a level walk', () {
      final random = math.Random(7);
      final noisy = activeCalories(
        track(metres: 5000, noise: (_) => (random.nextDouble() - .5) * 16),
        70,
      )!;
      expect(noisy, closeTo(175, 175 * .12));
    });

    test('unknown weight, stops, missing altitudes and GPS gaps', () {
      expect(activeCalories(track(metres: 1000), null), isNull);
      expect(
        activeCalories(track(metres: 1000, altitude: false), 70),
        closeTo(activeCalories(track(metres: 1000), 70)!, .01),
      );
      final start = DateTime(2026, 9, 28, 8);
      final standing = [
        for (var i = 0; i < 60; i++)
          WalkSample(start.add(Duration(seconds: 5 * i)), at(0, 0), 5, 0),
      ];
      expect(activeCalories(standing, 70), 0);
      final gap = [
        WalkSample(start, at(0, 0), 5, 0),
        WalkSample(start.add(const Duration(minutes: 5)), at(400, 0), 5, 0),
      ];
      expect(activeCalories(gap, 70), 0);
    });

    test('profile weights are validated and the pack adds to the mass', () {
      expect(const WalkerProfile(weightKg: 70, packKg: 8).massKg, 78);
      expect(const WalkerProfile(packKg: 8).massKg, isNull);
      expect(WalkerProfile.validWeight(20), isFalse);
      expect(WalkerProfile.validWeight(null), isTrue);
      expect(WalkerProfile.validPack(61), isFalse);
    });
  });

  group('steps', () {
    WalkRecording recording() => WalkRecording(
      Trail(
        id: 'w',
        name: 'W',
        segments: [],
        pois: [],
        walk: WalkDetails(started: DateTime(2026, 9, 28), seconds: 0),
      ),
    );

    test('only active periods count, across pauses and a phone restart', () {
      final walk = recording();
      final t = DateTime(2026, 9, 28, 8);
      expect(walk.steps, isNull, reason: 'unknown until the sensor reports');
      walk.resume(t);
      walk.countSteps(10000);
      walk.countSteps(10500);
      walk.pause(t);
      walk.countSteps(12000); // walking while paused is ignored
      walk.resume(t);
      walk.countSteps(12000);
      walk.countSteps(12300);
      walk.countSteps(40); // counter reset by a phone restart
      walk.countSteps(240);
      expect(walk.steps, 500 + 300 + 200);
      expect(walk.snapshot(t).walk!.steps, 1000);
    });

    test(
      'recorder counts steps while recording and stops the sensor',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openLocalDatabase(inMemoryDatabasePath);
        final gps = _Gps(), sensor = FakeSteps()..counter = 5000;
        final service = RecordWalk(
          SqliteRecordingStore(db),
          SqliteTrailRepository(db),
          gps,
          () => 'walk',
          steps: sensor,
        )..massKg = 70;
        await service.start();
        sensor.counter = 5420;
        gps.events.add(Fix(const GeoPoint(49, 4, 100), 5, DateTime.now()));
        await pumpEventQueue();
        final walk = await service.finish();
        expect(walk!.walk!.steps, 420);
        expect(sensor.stopped, 1);
        expect(walk.walk!.estimatedCalories, 0, reason: 'one fix, no movement');
        await service.close();
        await gps.events.close();
        await db.close();
      },
    );

    test('refused step access leaves steps unknown, not zero', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openLocalDatabase(inMemoryDatabasePath);
      final gps = _Gps();
      final service = RecordWalk(
        SqliteRecordingStore(db),
        SqliteTrailRepository(db),
        gps,
        () => 'walk',
        steps: FakeSteps(allowed: false)..counter = 5000,
      );
      await service.start();
      final walk = await service.finish();
      expect(walk!.walk!.steps, isNull);
      expect(walk.walk!.estimatedCalories, isNull, reason: 'no weight');
      await service.close();
      await gps.events.close();
      await db.close();
    });

    test('walk measures round-trip; imported watch values take precedence', () {
      final walk = Trail(
        id: 'w',
        name: 'W',
        segments: [],
        pois: [],
        walk: WalkDetails(
          started: DateTime.utc(2026, 9, 28, 8),
          ended: DateTime.utc(2026, 9, 28, 9),
          seconds: 3600,
          steps: 6200,
          estimatedCalories: 181.5,
        ),
      );
      final decoded = TrailCodec.decode(TrailCodec.encode(walk)).walk!;
      expect(decoded.steps, 6200);
      expect(decoded.estimatedCalories, 181.5);
      expect(decoded.bestCalories, 181.5);
      final watch = decoded.withHealth(
        HealthSummary(
          readAt: DateTime.utc(2026, 9, 28, 10),
          sources: const ['watch'],
          steps: 6350,
          activeCalories: 205,
        ),
      );
      expect(watch.bestSteps, 6350);
      expect(watch.bestCalories, 205);
      expect(watch.estimatedCalories, 181.5, reason: 'estimate kept');
    });
  });

  group('walker profile sync', () {
    SynchronizeLibrary sync(MemoryProfiles store, FakeProfileTransport api) {
      final none = _NoSync();
      return SynchronizeLibrary(
        none,
        none,
        profile: (transport: api, store: store),
      );
    }

    test('the account profile restores on a new phone', () async {
      final store = MemoryProfiles(), api = FakeProfileTransport();
      await sync(store, api).synchronize();
      expect(store.profile.weightKg, 80);
      expect(store.pending, isFalse);
    });

    test(
      'a local change is sent, and one made meanwhile stays pending',
      () async {
        final store = MemoryProfiles()
          ..profile = const WalkerProfile(weightKg: 72)
          ..pending = true;
        final api = FakeProfileTransport();
        api.duringSend = () {
          store.profile = const WalkerProfile(weightKg: 73);
        };
        await sync(store, api).synchronize();
        expect(api.sent.single.weightKg, 72);
        expect(store.profile.weightKg, 73);
        expect(store.pending, isTrue);
        api.duringSend = null;
        await sync(store, api).synchronize();
        expect(api.remote.weightKg, 73);
        expect(store.pending, isFalse);
      },
    );

    test('the profile is stored per account database', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openLocalDatabase(inMemoryDatabasePath);
      final store = SqliteProfileStore(db);
      expect((await store.read()).profile.massKg, isNull);
      await store.save(
        const WalkerProfile(weightKg: 68.5, packKg: 6),
        pending: true,
      );
      final read = await store.read();
      expect(read.profile.massKg, 74.5);
      expect(read.pending, isTrue);
      await db.close();
    });
  });

  test('summaries say steps and active calories in both languages', () async {
    await initializeDateFormatting();
    final recap = WalkRecap(
      kilometre: 4,
      metres: 4000,
      activeSeconds: 2880,
      clock: DateTime(2026, 9, 28, 10),
      steps: 5234,
      calories: 140.4,
    );
    final fr = describeRecap(
      lookupAppLocalizations(const Locale('fr')),
      recap,
    ).lines;
    final en = describeRecap(
      lookupAppLocalizations(const Locale('en')),
      recap,
    ).lines;
    expect(fr[RecapItem.steps], matches(RegExp(r'^5\s234 pas\.$')));
    expect(fr[RecapItem.calories], '140 kcal actives brûlées, estimation.');
    expect(en[RecapItem.steps], '5,234 steps.');
    expect(en[RecapItem.calories], '140 active kcal burned, estimated.');
    expect(recap.available, containsAll([RecapItem.steps, RecapItem.calories]));
    expect(
      RecapItem.spokenByDefault,
      containsAll([RecapItem.steps, RecapItem.calories]),
    );
  });
}
