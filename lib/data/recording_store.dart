import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../domain/walk_recording.dart';
import 'trail_codec.dart';

class SqliteRecordingStore implements RecordingStore {
  const SqliteRecordingStore(this.db);
  final Database db;
  @override
  Future<Trail?> read() async {
    final rows = await db.query(
      'settings',
      where: 'key=?',
      whereArgs: ['current-walk'],
    );
    return rows.isEmpty
        ? null
        : TrailCodec.decode(jsonDecode(rows.single['value'] as String));
  }

  @override
  Future<void> write(Trail recording) async {
    await db.insert('settings', {
      'key': 'current-walk',
      'value': jsonEncode(TrailCodec.encode(recording)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear() async {
    await db.delete('settings', where: 'key=?', whereArgs: ['current-walk']);
  }
}
