import 'package:gpix/domain/app_message.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/data/server_connection.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/data/gpx_text.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'auth_session_test.dart' show MemoryCredentials, environment, data;
import 'lifecycle_test.dart' as fixtures;

void main() {
  test('declared XML encodings and BOMs preserve accents without replacing bad bytes', () {
    const xml =
        '<gpx><wpt lat="49" lon="4"><name>Hébergement été</name></wpt></gpx>';
    expect(decodeGpxBytes([239, 187, 191, ...utf8.encode(xml)]), xml);
    for (final little in [true, false]) {
      final bytes = <int>[
        if (little) ...[255, 254] else ...[254, 255],
      ];
      for (final c in xml.codeUnits) {
        bytes.addAll(little ? [c & 255, c >> 8] : [c >> 8, c & 255]);
      }
      expect(decodeGpxBytes(bytes), xml);
    }
    final latin = '<?xml version="1.0" encoding="ISO-8859-1"?>$xml';
    expect(decodeGpxBytes(latin1.encode(latin)), latin);
    const cp =
        '<?xml version="1.0" encoding="windows-1252"?><gpx>Église l’étoile</gpx>';
    expect(
      decodeGpxBytes(cp.runes.map((c) => c == 0x2019 ? 0x92 : c).toList()),
      cp,
    );
    expect(
      () => decodeGpxBytes([
        60,
        103,
        112,
        120,
        62,
        233,
        60,
        47,
        103,
        112,
        120,
        62,
      ]),
      throwsFormatException,
    );
    expect(() => decodeGpxBytes([255, 254, 0]), throwsFormatException);
  });
  test('GPX names and descriptions survive SQLite, HTTP sync and a fresh device database', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('gpix-unicode-');
    final first = await openLocalDatabase('${directory.path}/first.sqlite');
    final second = await openLocalDatabase('${directory.path}/second.sqlite');
    final rows = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode(data()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/sync')) {
        final body =
            jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
        rows.add({...body, 'revision': 1});
        return http.Response(
          '{"revision":1,"conflict":false}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode(rows)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(() async {
      client.close();
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    });
    final server = ServerConnection(
      client,
      environment: environment,
      credentials: MemoryCredentials(),
    );
    await server.login('user', 'Testing123');
    final trails = XmlGpxDecoder().decode(
      decodeGpxBytes(
        utf8.encode(
          '<gpx><wpt lat="49" lon="4"><name>Église où dormir ? 🥾</name><desc>À côté : cœur, forêt, São, 東京.</desc></wpt></gpx>',
        ),
      ),
      'Hébergements',
    );
    await SqliteTrailRepository(first).save(trails.single);
    await SynchronizeLibrary(
      SqliteSyncStore(first),
      ApiSyncTransport(server),
    ).synchronize();
    await SynchronizeLibrary(
      SqliteSyncStore(second),
      ApiSyncTransport(server),
    ).synchronize();
    final restored = (await SqliteTrailRepository(second).all()).single;
    expect(restored.name, 'Hébergements');
    expect(restored.pois.single.name, 'Église où dormir ? 🥾');
    expect(restored.pois.single.description, 'À côté : cœur, forêt, São, 東京.');
  });
  test('a damaged filename cannot silently become a stored GPX name', () {
    expect(
      () => XmlGpxDecoder().decode(
        '<gpx><wpt lat="49" lon="4"><name>Église</name></wpt></gpx>',
        '4 - H\uFFFDbergements_Reims_Paris_2019',
      ),
      throwsFormatException,
    );
    expect(
      () => XmlGpxDecoder().decode(
        '<gpx><wpt lat="49" lon="4"><name>H\uFFFDbergement</name></wpt></gpx>',
        'Lieux',
      ),
      throwsFormatException,
    );
  });
  test(
    'GPX import preserves accents in both the name and visible confirmation',
    () async {
      final app = fixtures.controller();
      addTearDown(app.dispose);
      await app.import(
        '<gpx><trk><name>Forêt à côté de l’église</name><trkseg><trkpt lat="49" lon="4"/><trkpt lat="49.01" lon="4.01"/></trkseg></trk></gpx>',
        'été.gpx',
      );
      expect(app.trails.single.name, 'Forêt à côté de l’église');
      expect((app.message as AppMessage).code, 'itemsSaved');
      expect((app.message as AppMessage).arguments, [1]);
    },
  );
  test('UTF-8 API errors preserve French accents and apostrophes', () async {
    final client = MockClient(
      (request) async => request.url.path.endsWith('/login')
          ? http.Response(
              jsonEncode(data()),
              200,
              headers: {'content-type': 'application/json'},
            )
          : http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'error': 'Échec : vérifiez l’accès à votre itinéraire.',
                }),
              ),
              422,
              headers: {'content-type': 'application/json'},
            ),
    );
    addTearDown(client.close);
    final server = ServerConnection(
      client,
      environment: environment,
      credentials: MemoryCredentials(),
    );
    await server.login('user', 'Testing123');
    await expectLater(
      server.request('/api/approach', body: {}),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.diagnostic,
          'French error',
          'Échec : vérifiez l’accès à votre itinéraire.',
        ),
      ),
    );
  });
  test('bundled app text contains no damaged UTF-8 sequences', () {
    final damaged = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final text = file.readAsStringSync();
      if (RegExp(
        '\u00c3[\u0080-\u00bf]|\u00c2[\u0080-\u00bf]|\ufffd|\u00e2\u20ac',
      ).hasMatch(text)) {
        damaged.add(file.path);
      }
    }
    expect(
      damaged,
      isEmpty,
      reason: 'French text must be saved as UTF-8, without double decoding.',
    );
  });
}
