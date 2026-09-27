import '../domain/app_message.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../domain/ports.dart';
import 'server_connection.dart';

Region regionFromJson(Map<String, dynamic> j) {
  final b = j['bounds'] as List;
  final r = Region(
    id: j['id'],
    name: j['name'],
    version: j['version'],
    bytes: j['bytes'],
    sha256: j['sha256'],
    url: j['url'],
    bounds: Bounds(
      (b[0] as num).toDouble(),
      (b[1] as num).toDouble(),
      (b[2] as num).toDouble(),
      (b[3] as num).toDouble(),
    ),
  );
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(r.id) ||
      !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(r.version) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(r.sha256) ||
      r.bytes <= 0 ||
      r.bounds.west > r.bounds.east ||
      r.bounds.south > r.bounds.north) {
    throw MessageFormatException(AppMessage.invalidMapCatalog);
  }
  return r;
}

Map<String, dynamic> regionToJson(Region r) => {
  'id': r.id,
  'name': r.name,
  'version': r.version,
  'bytes': r.bytes,
  'sha256': r.sha256,
  'url': r.url,
  'bounds': [r.bounds.west, r.bounds.south, r.bounds.east, r.bounds.north],
};

class OfflineMaps implements MapRepository {
  OfflineMaps(this.db, this.root, this.server);
  final Database db;
  final Directory root;
  final ServerConnection server;
  final Set<String> _busy = {};
  @override
  Future<String?> composeStyle(List<LocalMap> maps) async {
    if (maps.isEmpty) return null;
    if (maps.length == 1) return maps.first.stylePath;
    final sources = <String, dynamic>{}, layers = <dynamic>[];
    Map<String, dynamic>? first;
    for (var i = 0; i < maps.length; i++) {
      final style = jsonDecode(
        await File(maps[i].stylePath).readAsString(),
      ) as Map<String, dynamic>;
      first ??= style;
      for (final entry in (style['sources'] as Map<String, dynamic>).entries) {
        sources['r$i-${entry.key}'] = entry.value;
      }
      for (final layer in style['layers'] as List) {
        if (i > 0 && layer['type'] == 'background') continue;
        layers.add({
          ...layer,
          'id': 'r$i-${layer['id']}',
          if (layer['source'] != null) 'source': 'r$i-${layer['source']}',
        });
      }
    }
    final merged = {...first!, 'sources': sources, 'layers': layers};
    final path = '${root.path}/combined-style.json';
    await File(path).writeAsString(jsonEncode(merged), flush: true);
    return path;
  }

  @override
  Future<List<Region>> catalog() async =>
      ((await server.request('/api/regions')) as List)
          .map((j) => regionFromJson(j))
          .toList();
  @override
  Future<List<LocalMap>> installed() async {
    final maps = <LocalMap>[];
    for (final row in await db.query('maps')) {
      final directory = Directory(row['path'] as String);
      try {
        await validateBundle(directory);
        maps.add(
          LocalMap(
            regionFromJson(jsonDecode(row['manifest'] as String)),
            '${directory.path}/resolved-style.json',
          ),
        );
      } catch (_) {
        /* Corrupt or missing files never count as ready. */
      }
    }
    return maps;
  }

  @override
  Future<void> download(Region r, void Function(double) progress) async {
    if (!_busy.add(r.id)) throw MessageFailure(AppMessage.downloadRunning);
    final destination = Directory('${root.path}/${r.id}-${r.sha256}');
    final temporary = Directory('${destination.path}.staging');
    final archive = File('${destination.path}.part');
    final client = http.Client();
    try {
      final ready = await installed();
      if (ready.any(
        (m) => m.region.id == r.id && m.region.sha256 == r.sha256,
      )) {
        return;
      }
      await root.create(recursive: true);
      final uri = Uri.parse(r.url);
      if (!server.environment.permitsResource(uri)) {
        throw MessageFormatException(AppMessage.mapHttpsRequired);
      }
      final response = await server.download(uri, client);
      if (response.statusCode != 200) {
        throw HttpException('Carte : HTTP ${response.statusCode}');
      }
      final sink = archive.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          received += chunk.length;
          if (received > r.bytes) {
            throw MessageFormatException(AppMessage.incorrectPackageSize);
          }
          sink.add(chunk);
          progress(received / r.bytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received != r.bytes ||
          (await crypto.sha256.bind(archive.openRead()).first).toString() !=
              r.sha256) {
        throw MessageFormatException(AppMessage.packageIntegrityFailed);
      }
      if (await temporary.exists()) await temporary.delete(recursive: true);
      await temporary.create();
      final input = InputFileStream(archive.path);
      try {
        final contents = ZipDecoder().decodeStream(input);
        var unpacked = 0;
        for (final entry in contents) {
          final path = entry.name.replaceAll('\\', '/');
          if (path.startsWith('/') ||
              path.contains(':') ||
              path.split('/').contains('..') ||
              entry.isSymbolicLink) {
            throw MessageFormatException(AppMessage.forbiddenPackagePath);
          }
          unpacked += entry.size;
          if (unpacked > 20 * 1024 * 1024 * 1024) {
            throw MessageFormatException(AppMessage.unpackedPackageTooLarge);
          }
          if (!entry.isFile) continue;
          final file = File('${temporary.path}/$path');
          await file.parent.create(recursive: true);
          final output = OutputFileStream(file.path);
          try {
            entry.writeContent(output);
          } finally {
            await output.close();
          }
        }
      } finally {
        await input.close();
      }
      await validateBundle(temporary);
      // The database points to the previous version until the complete new directory is published.
      if (await destination.exists()) await destination.delete(recursive: true);
      await temporary.rename(destination.path);
      await validateBundle(destination);
      await db.insert('maps', {
        'id': r.id,
        'manifest': jsonEncode(regionToJson(r)),
        'path': destination.path,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await archive.delete();
    } finally {
      client.close();
      _busy.remove(r.id);
      if (await temporary.exists()) await temporary.delete(recursive: true);
      if (await archive.exists()) await archive.delete();
    }
  }

  @override
  Future<void> remove(String id) async {
    if (_busy.contains(id)) {
      throw MessageFailure(AppMessage.waitForDownload);
    }
    final rows = await db.query('maps', where: 'id=?', whereArgs: [id]);
    await db.delete('maps', where: 'id=?', whereArgs: [id]);
    for (final row in rows) {
      final d = Directory(row['path'] as String);
      if (await d.exists()) await d.delete(recursive: true);
    }
  }
}

/// Bundle manifest lists every resource with its SHA-256. No network dependency is allowed.
Future<void> validateBundle(Directory dir) async {
  final manifest = jsonDecode(
    await File('${dir.path}/bundle.json').readAsString(),
  ) as Map<String, dynamic>;
  final files = manifest['files'] as Map<String, dynamic>;
  if (!files.containsKey('style.json') ||
      !files.keys.any((p) => p.endsWith('.pmtiles'))) {
    throw MessageFormatException(AppMessage.missingMapArchive);
  }
  for (final entry in files.entries) {
    if (entry.key.contains('..') ||
        entry.key.contains(':') ||
        entry.key.startsWith('/') ||
        entry.key.contains('\\')) {
      throw MessageFormatException(AppMessage.invalidPath);
    }
    final f = File('${dir.path}/${entry.key}');
    if (!await f.exists() ||
        (await crypto.sha256.bind(f.openRead()).first).toString() !=
            entry.value) {
      throw MessageFormatException(AppMessage.damagedResource);
    }
    if (entry.key.endsWith('.pmtiles')) {
      final handle = await f.open();
      try {
        final header = await handle.read(127);
        if (header.length != 127 ||
            ascii.decode(header.sublist(0, 7), allowInvalid: true) !=
                'PMTiles' ||
            header[7] != 3) {
          throw MessageFormatException(AppMessage.invalidPmtiles);
        }
        final view = ByteData.sublistView(header);
        final length = await f.length();
        for (var offset = 8; offset <= 56; offset += 16) {
          if (view.getUint64(offset, Endian.little) +
                  view.getUint64(offset + 8, Endian.little) >
              length) {
            throw MessageFormatException(AppMessage.truncatedPmtiles);
          }
        }
      } finally {
        await handle.close();
      }
    }
  }
  final styleText = await File('${dir.path}/style.json').readAsString();
  final style = jsonDecode(styleText) as Map<String, dynamic>;
  if (style['version'] != 8) {
    throw MessageFormatException(AppMessage.unsupportedMapStyle);
  }
  for (final source in (style['sources'] as Map).values) {
    if (source['type'] != 'vector' ||
        source['url'] is! String ||
        !(source['url'] as String).startsWith('pmtiles://bundle://') ||
        source.containsKey('tiles')) {
      throw MessageFormatException(AppMessage.localPmtilesRequired);
    }
  }
  for (final key in ['glyphs', 'sprite']) {
    if (style[key] != null && !(style[key] as String).startsWith('bundle://')) {
      throw MessageFormatException(AppMessage.nonLocalGraphics);
    }
  }
  void check(dynamic value) {
    if (value is Map) {
      value.values.forEach(check);
    }
    if (value is List) {
      value.forEach(check);
    }
    if (value is String &&
        RegExp(r'^(https?|file|asset|pmtiles)://').hasMatch(value) &&
        !value.startsWith('pmtiles://bundle://')) {
      throw MessageFormatException(AppMessage.externalMapResource);
    }
    if (value is String && value.contains('bundle://')) {
      final path = value.substring(value.indexOf('bundle://') + 9);
      if (path.contains('{')) {
        if (path != 'glyphs/{fontstack}/{range}.pbf') {
          throw MessageFormatException(AppMessage.unsupportedGlyphTemplate);
        }
        final fonts = manifest['fonts'] as List? ?? [];
        if (fonts.isEmpty) {
          throw MessageFormatException(AppMessage.missingFonts);
        }
        for (final font in fonts) {
          for (var start = 0; start < 65536; start += 256) {
            if (!files.containsKey('glyphs/$font/$start-${start + 255}.pbf')) {
              throw MessageFormatException(AppMessage.incompleteGlyphs);
            }
          }
        }
      } else if (!files.containsKey(path)) {
        for (final suffix in ['.json', '.png', '@2x.json', '@2x.png']) {
          if (!files.containsKey('$path$suffix')) {
            throw MessageFormatException(AppMessage.undeclaredResource);
          }
        }
      }
    }
  }

  check(style);
  final uri = dir.uri.toString().replaceFirst(RegExp(r'/$'), '');
  await File('${dir.path}/resolved-style.json')
      .writeAsString(styleText.replaceAll('bundle://', '$uri/'), flush: true);
}
