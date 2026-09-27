import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gpix/data/account_storage.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/domain/auth.dart';
import 'package:gpix/domain/models.dart';

void main() {
  test('account switch preserves SQLite library, pending edits and conflicts without sharing', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('gpix-auth-sqlite');
    try {
      const a = AuthUser(id: 'a', username: 'a', email: 'a@example.test'),
          b = AuthUser(id: 'b', username: 'b', email: 'b@example.test');
      final storageA = await AccountStorage.resolve(dir, 'prod:server', a);
      final dbA = await openLocalDatabase(storageA.databasePath);
      await SqliteTrailRepository(dbA).save(
        Trail(
          id: 'private-a',
          name: 'Private A',
          segments: [
            [const GeoPoint(0, 0), const GeoPoint(.1, .1)],
          ],
          pois: [],
        ),
      );
      final outbox = SqliteSyncStore(dbA);
      final edit = await outbox.next();
      expect(edit, isNotNull);
      await outbox.conflict(edit!);
      await dbA.close();
      final storageB = await AccountStorage.resolve(dir, 'prod:server', b);
      final dbB = await openLocalDatabase(storageB.databasePath);
      expect(await SqliteTrailRepository(dbB).all(), isEmpty);
      expect(await SqliteSyncStore(dbB).next(), isNull);
      await dbB.close();
      final reopened = await openLocalDatabase(
        (await AccountStorage.resolve(dir, 'prod:server', a)).databasePath,
      );
      expect(
        (await SqliteTrailRepository(reopened).all()).single.id,
        'private-a',
      );
      final rows = await reopened.query('outbox');
      expect(rows.single['operation'], edit.operationId);
      expect(rows.single['blocked'], 1);
      await reopened.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
