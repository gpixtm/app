import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/domain/models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test(
    'durable outbox survives lost ACK, later edit, restart and tombstone',
    () async {
      final dir = await Directory.systemTemp.createTemp('gpix-test');
      var db = await openLocalDatabase('${dir.path}/library.db');
      var repository = SqliteTrailRepository(db);
      var store = SqliteSyncStore(db);
      Trail t(String name) => Trail(
        id: 'id',
        name: name,
        segments: [
          [const GeoPoint(0, 0), const GeoPoint(0, .01)],
        ],
        pois: [],
      );
      await repository.save(t('first'));
      final sent = (await store.next())!;
      await repository.save(t('second'));
      await db.close();
      db = await openLocalDatabase('${dir.path}/library.db');
      repository = SqliteTrailRepository(db);
      store = SqliteSyncStore(db);
      final replay = (await store.next())!;
      expect(replay.operationId, sent.operationId);
      expect(replay.trail.name, 'first');
      expect(replay.revision, 0);
      await store.acknowledge(replay, 1);
      final edit = (await store.next())!;
      expect(edit.trail.name, 'second');
      expect(edit.revision, 1);
      expect(edit.operationId, isNot(sent.operationId));
      await store.acknowledge(edit, 2);
      await repository.delete('id');
      expect(await repository.all(), isEmpty);
      final deletion = (await store.next())!;
      expect(deletion.deleted, true);
      expect(deletion.revision, 2);
      await store.acknowledge(deletion, 3);
      expect(await store.next(), isNull);
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
