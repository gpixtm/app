import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/catalogue.dart';
import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/shared_trails.dart';
import '../domain/sync.dart';
import '../domain/trail_statistics.dart';
import 'catalogue_codec.dart';
import 'shared_trail_codec.dart';
import 'trail_codec.dart';

Future<Database> openLocalDatabase(String path) => openDatabase(
  path,
  version: 4,
  onUpgrade: (db, from, _) async {
    if (from < 2) await _createStatistics(db);
    if (from < 3) {
      await db.execute('ALTER TABLE trails ADD COLUMN public_id TEXT');
      await _createSharing(db);
    }
    if (from < 4) await _browseCatalogue(db);
  },
  onCreate: (db, _) async {
    await _createStatistics(db);
    await _createSharing(db);
    await db.execute(
      'CREATE TABLE trails (id TEXT PRIMARY KEY, payload TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0, mutation TEXT NOT NULL, public_id TEXT)',
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
    await _browseCatalogue(db);
  },
);

/// Version 2: offline cache of the API's running statistics per followed GPX.
Future<void> _createStatistics(DatabaseExecutor db) => db.execute(
  'CREATE TABLE trail_statistics (trail_id TEXT PRIMARY KEY, walks INTEGER NOT NULL, metres REAL NOT NULL, seconds INTEGER NOT NULL)',
);

/// Version 3: the last reviews read and places added on shared trails.
/// `trails.public_id` links a library entry to the shared trail it published
/// or reused. (Version 3 also cached the whole catalogue; version 4 drops it.)
Future<void> _createSharing(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE trail_reviews (trail_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
  );
  // `pending` is 'save' or 'delete' until sent; `version` detects a newer
  // local edit made while a request was in flight.
  await db.execute(
    'CREATE TABLE trail_places (id TEXT PRIMARY KEY, trail_id TEXT NOT NULL, change INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL, pending TEXT, version INTEGER NOT NULL DEFAULT 0)',
  );
}

/// Version 4: the catalogue is browsed on the server, never copied. Only the
/// details of trails made available offline are kept, beside their copy.
Future<void> _browseCatalogue(DatabaseExecutor db) async {
  await db.execute('DROP TABLE IF EXISTS shared_trails');
  await db.delete(
    'settings',
    where: 'key=?',
    whereArgs: ['shared-trails-cursor'],
  );
  await db.execute(
    'CREATE TABLE catalogue_details (trail_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
  );
}

const _placeCursor = 'trail-places-cursor';

class SqliteSharedTrailStore implements SharedTrailStore {
  const SqliteSharedTrailStore(this.db);
  final Database db;

  @override
  Future<void> keepDetails(String trailId, TrailDetails details) =>
      db.insert('catalogue_details', {
        'trail_id': trailId,
        'payload': jsonEncode(CatalogueCodec.encodeDetails(details)),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<TrailDetails?> details(String trailId) async {
    final rows = await db.query(
      'catalogue_details',
      where: 'trail_id=?',
      whereArgs: [trailId],
    );
    return rows.isEmpty
        ? null
        : CatalogueCodec.details(jsonDecode(rows.first['payload'] as String));
  }

  @override
  Future<void> forgetDetails(String trailId) =>
      db.delete('catalogue_details', where: 'trail_id=?', whereArgs: [trailId]);

  @override
  Future<TrailReviews?> reviews(String trailId) async {
    final rows = await db.query(
      'trail_reviews',
      where: 'trail_id=?',
      whereArgs: [trailId],
    );
    return rows.isEmpty
        ? null
        : SharedTrailCodec.decodeReviews(
            jsonDecode(rows.first['payload'] as String),
          );
  }

  @override
  Future<int> placeCursor() async {
    final rows = await db.query(
      'settings',
      where: 'key=?',
      whereArgs: [_placeCursor],
    );
    return rows.isEmpty ? 0 : int.parse(rows.first['value'] as String);
  }

  @override
  Future<void> applyPlaces(TrailPlacePage page) => db.transaction((txn) async {
    for (final place in page.places) {
      final local = await txn.query(
        'trail_places',
        columns: ['pending'],
        where: 'id=? AND pending IS NOT NULL',
        whereArgs: [place.id],
      );
      if (local.isNotEmpty) continue;
      if (place.deleted) {
        await txn.delete('trail_places', where: 'id=?', whereArgs: [place.id]);
      } else {
        await txn.insert('trail_places', {
          'id': place.id,
          'trail_id': place.trailId,
          'change': place.change,
          'payload': jsonEncode(SharedTrailCodec.encodePlace(place)),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await txn.insert('settings', {
      'key': _placeCursor,
      'value': '${page.next}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  @override
  Future<List<TrailPlace>> places() async =>
      (await db.query(
            'trail_places',
            where: "pending IS NULL OR pending = 'save'",
            orderBy: 'rowid',
          ))
          .map(
            (r) => SharedTrailCodec.decodePlace(
              jsonDecode(r['payload'] as String),
              pending: r['pending'] != null,
            ),
          )
          .toList();

  @override
  Future<void> savePlace(TrailPlace place) => db.rawInsert(
    "INSERT INTO trail_places(id, trail_id, change, payload, pending, version) VALUES(?, ?, ?, ?, 'save', 1) ON CONFLICT(id) DO UPDATE SET trail_id=excluded.trail_id, payload=excluded.payload, pending='save', version=trail_places.version+1",
    [
      place.id,
      place.trailId,
      place.change,
      jsonEncode(SharedTrailCodec.encodePlace(place)),
    ],
  );

  @override
  Future<void> removePlace(TrailPlace place) => db.transaction((txn) async {
    // A place never received by the server simply disappears.
    final unsent = await txn.delete(
      'trail_places',
      where: "id=? AND pending='save' AND change=0",
      whereArgs: [place.id],
    );
    if (unsent == 0) {
      await txn.rawUpdate(
        "UPDATE trail_places SET pending='delete', version=version+1 WHERE id=?",
        [place.id],
      );
    }
  });

  @override
  Future<List<PendingPlace>> pendingPlaces() async {
    final rows = await db.rawQuery(
      'SELECT p.payload, p.pending, p.version, COALESCE((SELECT t.public_id FROM trails t WHERE t.id = p.trail_id AND t.public_id IS NOT NULL), p.trail_id) AS resolved FROM trail_places p WHERE p.pending IS NOT NULL ORDER BY p.rowid',
    );
    return [
      for (final r in rows)
        PendingPlace(
          SharedTrailCodec.decodePlace({
            ...jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            'trailId': r['resolved'],
          }, pending: true),
          r['pending'] == 'delete',
          r['version'] as int,
        ),
    ];
  }

  @override
  Future<void> placeSent(PendingPlace sent, TrailPlace? result) async {
    if (result == null || sent.delete || result.deleted) {
      await db.delete(
        'trail_places',
        where: 'id=? AND version=?',
        whereArgs: [sent.place.id, sent.version],
      );
      return;
    }
    await db.update(
      'trail_places',
      {
        'trail_id': result.trailId,
        'change': result.change,
        'payload': jsonEncode(SharedTrailCodec.encodePlace(result)),
        'pending': null,
      },
      where: 'id=? AND version=?',
      whereArgs: [sent.place.id, sent.version],
    );
  }

  @override
  Future<void> keepReviews(TrailReviews reviews) => db.insert('trail_reviews', {
    'trail_id': reviews.trailId,
    'payload': jsonEncode(SharedTrailCodec.encodeReviews(reviews)),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

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
  Future<List<Trail>> all() async =>
      (await db.query('trails', where: 'deleted = 0', orderBy: 'rowid DESC'))
          .map(
            (r) =>
                TrailCodec.decode(jsonDecode(r['payload'] as String))
                    .withPublicId(r['public_id'] as String?),
          )
          .toList();
  @override
  Future<Set<String>> offlineCopies() async => {
    for (final r in await db.rawQuery(
      'SELECT id FROM trails t WHERE deleted = 0 AND revision = 0 AND dirty = 0 AND public_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM outbox o WHERE o.id = t.id)',
    ))
      r['id'] as String,
  };

  @override
  Future<void> save(Trail trail) => db.transaction(
    (txn) =>
        enqueue(txn, trail.id, jsonEncode(TrailCodec.encode(trail)), false),
  );

  /// A downloaded shared trail stays on this phone without becoming a private
  /// copy: nothing is queued until the walker changes it, for example by
  /// planning days. Reopening a trail the walker deleted brings it back to
  /// their library.
  @override
  Future<void> keep(Trail trail) => db.transaction((txn) async {
    final rows = await txn.query(
      'trails',
      columns: ['deleted'],
      where: 'id=?',
      whereArgs: [trail.id],
    );
    if (rows.isEmpty) {
      await txn.insert('trails', {
        'id': trail.id,
        'payload': jsonEncode(TrailCodec.encode(trail)),
        'revision': 0,
        'dirty': 0,
        'deleted': 0,
        'mutation': const Uuid().v4(),
        'public_id': trail.sharedId,
      });
    } else if (rows.first['deleted'] == 1) {
      await enqueue(txn, trail.id, jsonEncode(TrailCodec.encode(trail)), false);
    }
  });

  @override
  Future<void> delete(String id) => db.transaction((txn) async {
    final rows = await txn.query('trails', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final queued = await txn.query(
      'outbox',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    // A shared trail only kept on this phone was never in the account.
    if (rows.first['revision'] == 0 && queued.isEmpty) {
      await txn.delete('trails', where: 'id=?', whereArgs: [id]);
      return;
    }
    await enqueue(txn, id, rows.first['payload'] as String, true);
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
  Future<void> acknowledge(
    SyncOperation op,
    int revision, {
    String? publicId,
  }) => db.transaction((txn) async {
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
      {
        'revision': revision,
        'dirty': remaining.isEmpty ? 0 : 1,
        'public_id': ?publicId,
      },
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
        'public_id': op.publicId,
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
