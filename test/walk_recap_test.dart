import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/application/announce_progress.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:gpix/data/android_guidance.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/sync.dart';
import 'package:gpix/domain/trail_geometry.dart';
import 'package:gpix/domain/trail_statistics.dart';
import 'package:gpix/domain/walk_recap.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:gpix/l10n/generated/app_localizations.dart';
import 'package:gpix/presentation/guidance_text.dart';

import 'guidance_test.dart' show RecordingOutput, at;

const usualTrail = '3f0c6c4e-5b1a-4c55-9d3e-2a0b7f6a1c01';

WalkRecording recording({String? source, double alreadyNorth = 0}) =>
    WalkRecording(
      Trail(
        id: 'walk',
        name: 'Walk',
        segments: [
          if (alreadyNorth > 0) [at(0, 0), at(alreadyNorth, 0)],
        ],
        pois: [],
        walk: WalkDetails(
          started: DateTime(2026, 9, 28, 8),
          seconds: 0,
          sourceTrailId: source,
        ),
      ),
    );

class MemoryStatistics implements TrailStatisticsStore {
  final values = <String, TrailStatistics>{};
  @override
  Future<TrailStatistics?> find(String trailId) async => values[trailId];
  @override
  Future<void> replaceAll(List<TrailStatistics> statistics) async => values
    ..clear()
    ..addEntries(statistics.map((s) => MapEntry(s.trailId, s)));
  @override
  Future<void> addWalk(Trail walk) async {}
}

/// Walk north from [from] metres in 10 m steps at [kmh], feeding [progress].
Future<DateTime> walkNorth(
  AnnounceProgress progress,
  WalkRecording walk, {
  required double from,
  required double to,
  required double kmh,
  required DateTime start,
  bool voice = true,
  bool foreground = false,
  TrackingSession? session,
}) async {
  final step = Duration(milliseconds: (10 / (kmh / 3.6) * 1000).round());
  var time = start;
  for (var d = from; d <= to; d += 10) {
    final fix = Fix(at(d, 0), 5, time);
    walk.accept(fix, time);
    session?.accept(fix, time);
    await progress.update(
      walk,
      now: time,
      voice: voice,
      foreground: foreground,
      session: session,
    );
    time = time.add(step);
  }
  return time;
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));
  setUpAll(initializeDateFormatting);

  test(
    'a summary is announced at each recorded kilometre, not before',
    () async {
      final output = RecordingOutput();
      final progress = AnnounceProgress(output);
      final walk = recording();
      final start = DateTime(2026, 9, 28, 8);
      walk.resume(start);
      await walkNorth(progress, walk, from: 0, to: 2050, kmh: 5, start: start);
      expect(output.recaps.map((r) => r.$1.kilometre), [1, 2]);
      final second = output.recaps.last.$1;
      expect(second.splitKmh, closeTo(5, .1));
      expect(second.averageKmh, closeTo(5, .1));
      // Free walk: nothing to compare with and no destination.
      expect(second.difference, isNull);
      expect(second.remainingMetres, isNull);
      expect(second.arrival, isNull);
      expect(output.recaps.last.$2, RecapItem.spokenByDefault);
      expect(output.recaps.last.$3, isTrue, reason: 'notified off-screen');
    },
  );

  test(
    'voice off and visible app: silent summary without notification',
    () async {
      final output = RecordingOutput();
      final progress = AnnounceProgress(output);
      final walk = recording();
      final start = DateTime(2026, 9, 28, 8);
      walk.resume(start);
      await walkNorth(
        progress,
        walk,
        from: 0,
        to: 1010,
        kmh: 5,
        start: start,
        voice: false,
        foreground: true,
      );
      expect(output.recaps.single.$2, isEmpty);
      expect(output.recaps.single.$3, isFalse);
    },
  );

  test(
    'a restored recording continues counting without a false current speed',
    () async {
      final output = RecordingOutput();
      final progress = AnnounceProgress(output);
      final walk = recording(alreadyNorth: 2400);
      final start = DateTime(2026, 9, 28, 9);
      walk.resume(start);
      await walkNorth(
        progress,
        walk,
        from: 2410,
        to: 3100,
        kmh: 5,
        start: start,
      );
      expect(output.recaps.single.$1.kilometre, 3);
      expect(output.recaps.single.$1.splitKmh, isNull);
    },
  );

  test('a usual GPX compares with its stored average and gives remaining and arrival', () async {
    final output = RecordingOutput();
    final statistics = MemoryStatistics()
      ..values[usualTrail] = const TrailStatistics(usualTrail, 4, 20000, 14400);
    final progress = AnnounceProgress(output, statistics: statistics);
    final trail = Trail(
      id: usualTrail,
      name: 'Usual',
      segments: [
        [at(0, 0), at(5000, 0)],
      ],
      pois: [],
    );
    final session = TrackingSession(TrailGeometry(trail))..resume();
    final walk = recording(source: usualTrail);
    final start = DateTime(2026, 9, 28, 8);
    walk.resume(start);
    await walkNorth(
      progress,
      walk,
      from: 0,
      to: 1010,
      kmh: 5.2,
      start: start,
      session: session,
    );
    final recap = output.recaps.single.$1;
    expect(recap.usualKmh, closeTo(5, 1e-9));
    expect(recap.previousWalks, 4);
    expect(recap.difference, closeTo(.2, .05));
    expect(recap.remainingMetres, closeTo(4000, 10));
    expect(
      recap.arrival!.difference(recap.clock).inMinutes,
      closeTo(4 / 5.2 * 60, 1),
    );
  });

  test(
    'summary sentences in English and French, faster, slower and as usual',
    () {
      WalkRecap recap(double average, {int seconds = 3900}) => WalkRecap(
        kilometre: 5,
        metres: 5000,
        activeSeconds: seconds,
        clock: DateTime(2026, 9, 28, 14, 5),
        splitKmh: 5.4,
        averageKmh: average,
        usualKmh: 5,
        previousWalks: 3,
        remainingMetres: 2500,
        arrival: DateTime(2026, 9, 28, 14, 35),
        ascent: 124.4,
      );
      final faster = describeRecap(fr, recap(5.2)).lines;
      expect(describeRecap(fr, recap(5.2)).title, 'Kilomètre 5');
      expect(faster[RecapItem.distance], '5 km parcourus.');
      expect(
        faster[RecapItem.duration],
        'En marche depuis 1 heure et 5 minutes.',
      );
      expect(faster[RecapItem.currentSpeed], 'Dernier kilomètre à 5,4 km/h.');
      expect(
        faster[RecapItem.comparison],
        '0,2 km/h plus rapide que votre moyenne habituelle de 5,0 km/h. '
        'Parcours déjà fait 3 fois.',
      );
      expect(faster[RecapItem.remaining], 'Encore 2,5 km.');
      expect(faster[RecapItem.arrival], 'Arrivée estimée à 14:35.');
      expect(faster[RecapItem.ascent], '124 m de dénivelé positif.');
      expect(faster[RecapItem.clock], 'Il est 14:05.');
      expect(
        describeRecap(en, recap(4.8)).lines[RecapItem.comparison],
        '0.2 km/h slower than your usual 5.0 km/h. Walked 3 times before.',
      );
      expect(
        describeRecap(en, recap(5.03)).lines[RecapItem.comparison],
        startsWith('Same speed as usual, 5.0 km/h.'),
      );
      expect(
        describeRecap(en, recap(5, seconds: 60)).lines[RecapItem.duration],
        'Walking for 1 minute.',
      );
    },
  );

  test(
    'only selected items are spoken; the notification lists them all',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('gpix/guidance-test');
      final calls = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.arguments as Map<Object?, Object?>);
            return null;
          });
      final guidance = AndroidGuidance(
        sentences: (_) => (title: '', body: '', speech: ''),
        recapSentences: (recap) => describeRecap(en, recap),
        languageCode: () => 'en',
        channel: channel,
      );
      final recap = WalkRecap(
        kilometre: 2,
        metres: 2000,
        activeSeconds: 1440,
        clock: DateTime(2026, 9, 28, 9),
        averageKmh: 5,
      );
      await guidance.summarize(
        recap,
        spoken: {RecapItem.averageSpeed},
        notify: true,
      );
      expect(calls.single['kind'], 'recap');
      expect(calls.single['speech'], 'Kilometre 2. Average speed 5.0 km/h.');
      expect(
        calls.single['body'],
        '2 km walked.\nWalking for 24 minutes.\nAverage speed 5.0 km/h.\nIt is 9:00 AM.',
      );
      expect(calls.single['speak'], isTrue);
      calls.clear();
      await guidance.summarize(recap, spoken: const {}, notify: false);
      expect(calls, isEmpty);
    },
  );

  test('spoken item preference survives save and ignores unknown names', () {
    expect(RecapItem.parse(null), RecapItem.spokenByDefault);
    expect(RecapItem.parse(''), isEmpty);
    expect(RecapItem.parse('clock,unknown,distance'), {
      RecapItem.distance,
      RecapItem.clock,
    });
    expect(
      RecapItem.format({RecapItem.clock, RecapItem.distance}),
      'distance,clock',
    );
  });

  group('statistics cache', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    Trail finishedWalk({String? source, String? route, double north = 1000}) =>
        Trail(
          id: 'w-$north',
          name: 'Walk',
          segments: [
            [at(0, 0), at(north, 0)],
          ],
          pois: [],
          walk: WalkDetails(
            started: DateTime.utc(2026, 9, 28, 8),
            ended: DateTime.utc(2026, 9, 28, 9),
            seconds: 720,
            sourceTrailId: source,
            routeId: route,
          ),
        );

    test('eligible walks follow the API rule, including linked free walks', () {
      expect(
        WalkContribution.of(finishedWalk(source: usualTrail))!.trailId,
        usualTrail,
      );
      expect(
        WalkContribution.of(finishedWalk(route: usualTrail))!.trailId,
        usualTrail,
      );
      expect(WalkContribution.of(finishedWalk()), isNull);
      expect(
        WalkContribution.of(finishedWalk(source: usualTrail, north: 300)),
        isNull,
      );
    });

    test(
      'route link round-trips and legacy payloads without it still decode',
      () {
        final encoded = TrailCodec.encode(finishedWalk(route: usualTrail));
        expect(TrailCodec.decode(encoded).walk!.routeId, usualTrail);
        final legacy = TrailCodec.encode(finishedWalk(source: usualTrail));
        expect((legacy['walk'] as Map).containsKey('routeId'), isFalse);
        expect(TrailCodec.decode(legacy).walk!.statisticsTrailId, usualTrail);
      },
    );

    test('offline increments, then server totals replace the cache', () async {
      final db = await openLocalDatabase(inMemoryDatabasePath);
      final store = SqliteTrailStatisticsStore(db);
      await store.addWalk(finishedWalk(route: usualTrail));
      await store.addWalk(finishedWalk(route: usualTrail, north: 2000));
      final cached = (await store.find(usualTrail))!;
      expect(cached.walks, 2);
      expect(cached.seconds, 1440);
      expect(cached.metres, closeTo(3000, 1));
      await store.replaceAll([
        const TrailStatistics(usualTrail, 7, 35000, 25200),
      ]);
      expect((await store.find(usualTrail))!.averageKmh, closeTo(5, 1e-9));
      await db.close();
    });

    test('upgrading a version 1 database keeps its data and adds the cache', () async {
      final directory = await Directory.systemTemp.createTemp('gpix-upgrade');
      final path = '${directory.path}/v1.sqlite';
      final v1 = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE trails (id TEXT PRIMARY KEY, payload TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0, mutation TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE outbox (sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, operation TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, deleted INTEGER NOT NULL, base INTEGER, blocked INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE maps (id TEXT PRIMARY KEY, manifest TEXT NOT NULL, path TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      );
      await SqliteTrailRepository(v1).save(finishedWalk(source: usualTrail));
      await v1.close();
      final upgraded = await openLocalDatabase(path);
      expect(await upgraded.getVersion(), 5);
      final trails = await SqliteTrailRepository(upgraded).all();
      expect(trails.single.walk!.sourceTrailId, usualTrail);
      expect(await SqliteSyncStore(upgraded).next(), isNotNull);
      await SqliteTrailStatisticsStore(upgraded).addWalk(trails.single);
      expect(
        (await SqliteTrailStatisticsStore(upgraded).find(usualTrail))!.walks,
        1,
      );
      await upgraded.close();
      await directory.delete(recursive: true);
    });

    test(
      'sync refreshes statistics and tolerates an API without them',
      () async {
        final store = MemoryStatistics();
        final transport = _Transport();
        final sync = SynchronizeLibrary(
          _EmptySyncStore(),
          transport,
          statistics: (transport: transport, store: store),
        );
        await sync.synchronize();
        expect((await store.find(usualTrail))!.walks, 3);
        transport.statisticsAvailable = false;
        await sync.synchronize();
        expect((await store.find(usualTrail))!.walks, 3, reason: 'cache kept');
      },
    );
  });
}

class _Transport implements SyncTransport, StatisticsTransport {
  bool statisticsAvailable = true;
  @override
  Future<SyncResult> push(SyncOperation operation) async =>
      SyncResult(1, false);
  @override
  Future<List<SyncOperation>> pull() async => [];
  @override
  Future<List<TrailStatistics>> fetch() async {
    if (!statisticsAvailable) throw const HttpException('404');
    return [const TrailStatistics(usualTrail, 3, 15000, 10800)];
  }
}

class _EmptySyncStore implements SyncStore {
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
}
