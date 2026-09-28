import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:gpix/domain/app_message.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/day_plan.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/server_connection.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:gpix/application/backend_environment.dart';
import 'package:gpix/domain/connection_settings.dart';

class _TestCredentials implements CredentialStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

// Test-only host transport. Production URL validation stays unchanged; the
// declared Android emulator origin is rewritten only inside this test client.
class _LoopbackTestClient extends http.BaseClient {
  final _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != 'http://10.0.2.2:8080') {
      throw StateError(
        'The loopback test adapter only accepts the fixed emulator origin.',
      );
    }
    final forwarded =
        http.Request(request.method, request.url.replace(host: '127.0.0.1'))
          ..followRedirects = false
          ..headers.addAll(request.headers)
          ..bodyBytes = await request.finalize().toBytes();
    return _inner.send(forwarded);
  }

  @override
  void close() => _inner.close();
}

void main() {
  final identifier = Platform.environment['GPIX_TEST_IDENTIFIER'];
  final password = Platform.environment['GPIX_TEST_PASSWORD'];
  test(
    'SQLite to real Symfony/Postgres: push, pull, conflict, preserve both and delete',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('gpix-api');
      final a = await openLocalDatabase('${dir.path}/a.db'),
          b = await openLocalDatabase('${dir.path}/b.db');
      final client = Platform.environment['GPIX_TEST_LOOPBACK'] == '1'
          ? _LoopbackTestClient()
          : http.Client();
      final url = Platform.environment['GPIX_TEST_URL']!;
      final server = ServerConnection(
        client,
        environment: BackendEnvironment(BackendMode.dev, url),
        credentials: _TestCredentials(),
      );
      final sa = SynchronizeLibrary(
            SqliteSyncStore(a),
            ApiSyncTransport(server),
          ),
          sb = SynchronizeLibrary(SqliteSyncStore(b), ApiSyncTransport(server));
      final ra = SqliteTrailRepository(a), rb = SqliteTrailRepository(b);
      final id = const Uuid().v4();
      Trail trail(String name) => Trail(
        id: id,
        name: name,
        segments: [
          [const GeoPoint(43, -1, 20), const GeoPoint(43.1, -1, 25)],
        ],
        pois: [],
        days: [const WalkingDay(0, 500), const WalkingDay(500, 1500)],
      );
      try {
        await server.login(identifier!, password!);
        await ra.save(trail('API integration'));
        await sa.synchronize();
        await sb.synchronize();
        expect((await rb.all()).any((t) => t.id == id), true);
        expect(
          (await rb.all())
              .singleWhere((t) => t.id == id)
              .days
              .map((d) => d.length),
          [500, 1000],
        );
        await ra.save(trail('A edit'));
        await rb.save(trail('B edit'));
        await sa.synchronize();
        expect(
          await sb.synchronize(),
          isA<AppMessage>().having((m) => m.code, 'code', 'syncConflicts'),
        );
        await sb.resolveConflicts();
        await sb.synchronize();
        final all = await rb.all();
        expect(all.any((t) => t.id == id && t.name == 'A edit'), true);
        final copy = all.singleWhere((t) => t.name == 'B edit · local copy');
        expect(copy.id, isNot(id));
        await rb.delete(copy.id);
        await rb.delete(id);
        await sb.synchronize();
        await sa.synchronize();
        expect(
          (await ra.all()).any((t) => t.id == id || t.id == copy.id),
          false,
        );
      } finally {
        await a.close();
        await b.close();
        client.close();
        await dir.delete(recursive: true);
      }
    },
    skip:
        identifier == null ||
            password == null ||
            Platform.environment['GPIX_TEST_URL'] == null
        ? 'Set GPIX_TEST_IDENTIFIER, GPIX_TEST_PASSWORD and GPIX_TEST_URL (LAN IP) to exercise a local running API'
        : false,
  );
}
