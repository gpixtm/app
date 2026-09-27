import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/day_plan.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:gpix/domain/walk_metrics.dart';
import 'package:gpix/domain/trail_geometry.dart';
import 'package:gpix/domain/heading.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/recording_store.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/sync.dart';
import 'package:gpix/presentation/map_features.dart';

Trail route(String id) => Trail(
  id: id,
  name: id,
  segments: [
    [const GeoPoint(0, 0, 100), const GeoPoint(0, .01, 120)],
    [const GeoPoint(1, 1, 500), const GeoPoint(1, 1.01, 490)],
  ],
  pois: [],
);

void main() {
  test(
    'central map includes every imported GPX and preserves segment gaps',
    () {
      final features =
          libraryFeatures([route('a'), route('b')])['features'] as List;
      expect(features, hasLength(4));
      expect((features[0]['geometry']['coordinates'] as List).last, [0.01, 0]);
      expect((features[1]['geometry']['coordinates'] as List).first, [1, 1]);
    },
  );
  test('day clipping follows the GPX, interpolates boundaries and supports reverse without bridging gaps', () {
    final g = TrailGeometry(route('r'));
    final portion = g.portion(500, 1500);
    expect(portion, hasLength(2));
    final clipped = Trail(id: 'clip', name: '', segments: portion, pois: []);
    expect(TrailGeometry(clipped).total, closeTo(1000, .2));
    final reversed = g.portion(1500, 500);
    expect(reversed.first.first.lat, portion.last.last.lat);
    expect(reversed.last.last.lon, portion.first.first.lon);
    expect(const WalkingDay(1, 2).valid(g.total), false);
    expect(WalkingDay(0, g.total + 1).valid(g.total), false);
  });
  test('camera dampens walking oscillations but follows a deliberate turn, including north crossing', () {
    final origin = DateTime.utc(2026);
    final arrow = HeadingFilter(seconds: .22, deadband: 1);
    final camera = HeadingFilter(seconds: .85, deadband: 3);
    arrow.add(0, origin);
    camera.add(0, origin);
    var largest = 0.0;
    for (var i = 1; i <= 100; i++) {
      final raw = i.isEven ? 16.0 : 344.0;
      final time = origin.add(Duration(milliseconds: i * 100));
      final filtered = camera.add(arrow.add(raw, time)!, time)!;
      final amplitude = angleDifference(filtered, 0).abs();
      if (amplitude > largest) largest = amplitude;
    }
    expect(largest, lessThan(4));
    for (var i = 101; i <= 130; i++) {
      final time = origin.add(Duration(milliseconds: i * 100));
      camera.add(arrow.add(90, time)!, time);
    }
    expect(angleDifference(camera.value!, 90).abs(), lessThan(6));
    final north = HeadingFilter(seconds: .22)..add(359, origin);
    north.add(1, origin.add(const Duration(milliseconds: 100)));
    expect(angleDifference(north.value!, 0).abs(), lessThan(2));
  });
  test('actual recorded path excludes poor GPS, jumps and pauses; metrics do not invent health data', () {
    final start = DateTime.utc(2026);
    final recording = WalkRecording(
      Trail(
        id: 'walk',
        name: 'Libre',
        segments: [],
        pois: [],
        walk: WalkDetails(started: start, seconds: 0),
      ),
    );
    recording.resume(start);
    bool add(int seconds, GeoPoint point, {double accuracy = 5}) {
      final time = start.add(Duration(seconds: seconds));
      return recording.accept(Fix(point, accuracy, time), time);
    }

    expect(add(0, const GeoPoint(0, 0, 100)), true);
    expect(add(10, const GeoPoint(0, .0001, 105)), true);
    expect(add(11, const GeoPoint(1, 1, 100)), false);
    expect(add(20, const GeoPoint(0, .0002, 106), accuracy: 70), false);
    expect(add(30, const GeoPoint(0, .0003, 107)), true);
    recording.pause(start.add(const Duration(seconds: 40)));
    recording.resume(start.add(const Duration(seconds: 100)));
    expect(add(100, const GeoPoint(0, .01, 300)), true);
    expect(add(110, const GeoPoint(0, .0101, 295)), true);
    recording.pause(start.add(const Duration(seconds: 120)));
    final trail = recording.snapshot(
      start.add(const Duration(seconds: 120)),
      finished: true,
    );
    expect(trail.segments, hasLength(3));
    final stats = WalkMetrics(trail);
    expect(stats.metres, closeTo(22.24, .1));
    expect(stats.activeSeconds, 60);
    expect(stats.elapsedSeconds, 120);
    expect(stats.ascent, 5);
    expect(stats.descent, 5);
    expect(trail.walk!.health, isNull);
    expect(
      TrailCodec.decode(TrailCodec.encode(trail)).walk!.samples,
      hasLength(5),
    );
  });
  test('offline days and completed history survive restart, outbox replay and restore onto another phone', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('gpix-experience');
    var a = await openLocalDatabase('${dir.path}/a.sqlite');
    final b = await openLocalDatabase('${dir.path}/b.sqlite');
    final dayTrail = route('route')
        .withDays([const WalkingDay(0, 500), const WalkingDay(500, 1500)]);
    await SqliteTrailRepository(a).save(dayTrail);
    final walk = Trail(
      id: 'walk',
      name: 'Libre',
      segments: dayTrail.segments,
      pois: [],
      walk: WalkDetails(
        started: DateTime.utc(2026),
        ended: DateTime.utc(2026, 1, 1, 1),
        seconds: 3000,
      ),
    );
    await SqliteRecordingStore(a).write(walk);
    await a.close();
    a = await openLocalDatabase('${dir.path}/a.sqlite');
    expect((await SqliteRecordingStore(a).read())!.walk!.seconds, 3000);
    await SqliteTrailRepository(a).save(walk);
    final outbox = SqliteSyncStore(a), remote = <SyncOperation>[];
    while (true) {
      final op = await outbox.next();
      if (op == null) break;
      // Exercise the actual wire codec, not shared object identity.
      remote.add(
        SyncOperation(
          op.id,
          op.operationId,
          1,
          false,
          TrailCodec.decode(TrailCodec.encode(op.trail)),
        ),
      );
      await outbox.acknowledge(op, 1);
    }
    await SqliteSyncStore(b).merge(remote);
    final restored = await SqliteTrailRepository(b).all();
    expect(
      restored.singleWhere((t) => t.id == 'route').days.map((d) => d.length),
      [500, 1000],
    );
    expect(restored.singleWhere((t) => t.id == 'walk').walk!.seconds, 3000);
    await a.close();
    await b.close();
    await dir.delete(recursive: true);
  });
}
