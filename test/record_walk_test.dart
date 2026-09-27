import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/recording_store.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';

class _Gps implements PositionSource {
  final events = StreamController<Fix>.broadcast();
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => events.stream;
}

void main() {
  test('recording checkpoints survive process restart paused; finish queues exactly one completed walk for sync', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('gpix-recording');
    var db = await openLocalDatabase('${directory.path}/recording.sqlite');
    final gps = _Gps();
    var service = RecordWalk(
      SqliteRecordingStore(db),
      SqliteTrailRepository(db),
      gps,
      () => 'walk',
    );
    await service.initialize();
    await service.start();
    gps.events.add(Fix(const GeoPoint(49, 4, 100), 5, DateTime.now()));
    await Future<void>.delayed(Duration.zero);
    await service.close();
    await db.close();
    db = await openLocalDatabase('${directory.path}/recording.sqlite');
    service = RecordWalk(
      SqliteRecordingStore(db),
      SqliteTrailRepository(db),
      gps,
      () => 'another-walk',
    );
    await service.initialize();
    expect(service.active, false);
    expect(service.current!.samples, hasLength(1));
    expect(await SqliteSyncStore(db).next(), isNull);
    final walk = await service.finish();
    expect(walk!.id, 'walk');
    expect(walk.walk!.ended, isNotNull);
    expect(await SqliteRecordingStore(db).read(), isNull);
    final pending = (await SqliteSyncStore(db).next())!;
    expect(pending.trail.walk!.samples, hasLength(1));
    expect(service.current, isNull);
    await service.close();
    await gps.events.close();
    await db.close();
    await directory.delete(recursive: true);
  });
}
