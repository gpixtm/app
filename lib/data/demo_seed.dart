import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../application/library.dart';
import 'offline_maps.dart';

Future<void> seedDemo(Database db, Directory root, Library library) async {
  if ((await db.query(
    'settings',
    where: 'key=?',
    whereArgs: ['demo'],
  )).isNotEmpty) {
    return;
  }
  final target = Directory('${root.path}/demo');
  await target.create(recursive: true);
  for (final file in ['map.pmtiles', 'style.json', 'bundle.json']) {
    final data = await rootBundle.load('assets/demo/$file');
    await File('${target.path}/$file').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  await validateBundle(target);
  await library.import(
    await rootBundle.loadString('assets/demo/walk.gpx'),
    "Demo",
  );
  final region = {
    'id': 'demo',
    'name': "Demo · Florence",
    'version': 'fixture-v3',
    'bytes': 6601156,
    'sha256': '0' * 64,
    'url': '',
    'bounds': [11.221144, 43.745121, 11.287543, 43.789306],
  };
  await db.insert('maps', {
    'id': 'demo',
    'manifest': jsonEncode(region),
    'path': target.path,
  });
  await db.insert('settings', {'key': 'demo', 'value': '1'});
}
