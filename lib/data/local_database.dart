import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/sync.dart';
import '../domain/trail_statistics.dart';
import 'trail_codec.dart';

Future<Database> openLocalDatabase(String path) => openDatabase(
  path,
  version: 2,
  onUpgrade: (db, from, _) async {
    if (from < 2) await _createStatistics(db);
  },
  onCreate: (db, _) async {
    await _createStatistics(db);
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

/// Version 2: offline cache of the API's running statistics per followed GPX.
Future<void> _createStatistics(DatabaseExecutor db) => db.execute(
  'CREATE TABLE trail_statistics (trail_id TEXT PRIMARY KEY, walks INTEGER NOT NULL, metres REAL NOT NULL, seconds INTEGER NOT NULL)',
);

class SqliteTrailStatisticsStore implements TrailStatisticsStore {
  const SqliteTrailStatisticsStore(this.db);
  final Database db;
  static TrailStatistics _read(Map<String, Object?> row) => TrailStatistics(
    row['trail_id'] as String,
    row['walks'] as int,
    (row['metres'] as num).toDouble(),
    row['seconds'] as int,
  );
  static Map<String, Object?> _row(TrailStatistics s) => {
    'trail_id': s.trailId,
    'walks': s.walks,
    'metres': s.metres,
    'seconds': s.seconds,
  };

  @override
  Future<TrailStatistics?> find(String trailId) async {
    final rows = await db.query(
      'trail_statistics',
      where: 'trail_id=?',
      whereArgs: [trailId],
    );
    return rows.isEmpty ? null : _read(rows.first);
  }

  @override
  Future<void> replaceAll(List<TrailStatistics> statistics) =>
      db.transaction((txn) async {
        await txn.delete('trail_statistics');
        for (final s in statistics) {
          await txn.insert('trail_statistics', _row(s));
        }
      });

  @override
  Future<void> addWalk(Trail walk) async {
    final contribution = WalkContribution.of(walk);
    if (contribution == null) return;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'trail_statistics',
        where: 'trail_id=?',
        whereArgs: [contribution.trailId],
      );
      final current = rows.isEmpty
          ? TrailStatistics(contribution.trailId, 0, 0, 0)
          : _read(rows.first);
      await txn.insert(
        'trail_statistics',
        _row(current.add(contribution)),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}

Future<void> enqueue(
  DatabaseExecutor db,
  String id,
  String payload,
  bool deleted,
) async {
  final operation = const Uuid().v4();
  await db.rawInsert(
    'INSERT INTO trails(id,payload,deleted,mutation) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload, deleted=excluded.deleted, mutation=excluded.mutation, dirty=1',
    [id, payload, deleted ? 1 : 0, operation],
  );
  await db.insert('outbox', {
    'id': id,
    'operation': operation,
    'payload': payload,
    'deleted': deleted ? 1 : 0,
  });
}

class SqliteTrailRepository implements TrailRepository {
  const SqliteTrailRepository(this.db);
  final Database db;
  @override
  Future<List<Trail>> all() async => (await db.query(
    'trails',
    where: 'deleted = 0',
    orderBy: 'rowid DESC',
  )).map((r) => TrailCodec.decode(jsonDecode(r['payload'] as String))).toList();
  @override
  Future<void> save(Trail trail) => db.transaction(
    (txn) =>
        enqueue(txn, trail.id, jsonEncode(TrailCodec.encode(trail)), false),
  );
  @override
  Future<void> delete(String id) => db.transaction((txn) async {
    final rows = await txn.query('trails', where: 'id=?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await enqueue(txn, id, rows.first['payload'] as String, true);
    }
  });
}

class SqliteSyncStore implements SyncStore {
  SqliteSyncStore(this.db, {this.localCopyName});
  final Database db;
  final String Function(String)? localCopyName;
  @override
  Future<int> conflictsCount() async =>
      (await db.rawQuery(
            'SELECT COUNT(DISTINCT id) AS n FROM outbox WHERE blocked=1',
          )).first['n']
          as int;
  @override
  Future<SyncOperation?> next() => db.transaction((txn) async {
    final rows = await txn.rawQuery(
      'SELECT o.* FROM outbox o WHERE o.id NOT IN (SELECT id FROM outbox WHERE blocked=1) ORDER BY sequence LIMIT 1',
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    var base = row['base'] as int?;
    if (base == null) {
      base =
          (await txn.query(
                'trails',
                columns: ['revision'],
                where: 'id=?',
                whereArgs: [row['id']],
              )).first['revision']
              as int;
      await txn.update(
        'outbox',
        {'base': base},
        where: 'operation=?',
        whereArgs: [row['operation']],
      );
    }
    return SyncOperation(
      row['id'] as String,
      row['operation'] as String,
      base,
      row['deleted'] == 1,
      TrailCodec.decode(jsonDecode(row['payload'] as String)),
    );
  });
  @override
  Future<void> acknowledge(SyncOperation op, int revision) =>
      db.transaction((txn) async {
        await txn.delete(
          'outbox',
          where: 'operation=?',
          whereArgs: [op.operationId],
        );
        final remaining = await txn.query(
          'outbox',
          columns: ['sequence'],
          where: 'id=?',
          whereArgs: [op.id],
          limit: 1,
        );
        await txn.update(
          'trails',
          {'revision': revision, 'dirty': remaining.isEmpty ? 0 : 1},
          where: 'id=?',
          whereArgs: [op.id],
        );
      });
  @override
  Future<void> conflict(SyncOperation op) async {
    await db.update(
      'outbox',
      {'blocked': 1},
      where: 'operation=?',
      whereArgs: [op.operationId],
    );
  }

  Future<void> _replace(DatabaseExecutor txn, SyncOperation op) => txn
      .insert('trails', {
        'id': op.id,
        'payload': jsonEncode(TrailCodec.encode(op.trail)),
        'revision': op.revision,
        'deleted': op.deleted ? 1 : 0,
        'dirty': 0,
        'mutation': op.operationId,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  @override
  Future<void> merge(List<SyncOperation> remote) => db.transaction((txn) async {
    for (final op in remote) {
      final row = await txn.query('trails', where: 'id=?', whereArgs: [op.id]);
      if (row.isNotEmpty && row.first['dirty'] == 1) continue;
      await _replace(txn, op);
    }
  });
  @override
  Future<void> preserveConflicts(List<SyncOperation> remote) =>
      db.transaction((txn) async {
        for (final op in remote) {
          final blocked = await txn.query(
            'outbox',
            where: 'id=? AND blocked=1',
            whereArgs: [op.id],
          );
          if (blocked.isEmpty) continue;
          final local = (await txn.query(
            'trails',
            where: 'id=?',
            whereArgs: [op.id],
          )).first;
          // Keep the latest local content as a clearly named new identity before accepting the server version.
          if (local['deleted'] == 0) {
            final p =
                jsonDecode(local['payload'] as String) as Map<String, dynamic>;
            p['id'] = const Uuid().v4();
            p['name'] =
                localCopyName?.call(p['name'] as String) ??
                "${p['name']} · local copy";
            await enqueue(txn, p['id'], jsonEncode(p), false);
          }
          await txn.delete('outbox', where: 'id=?', whereArgs: [op.id]);
          await _replace(txn, op);
        }
      });
}
