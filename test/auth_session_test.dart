import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/application/auth_controller.dart';
import 'package:gpix/application/backend_environment.dart';
import 'package:gpix/data/account_storage.dart';
import 'package:gpix/data/server_connection.dart';
import 'package:gpix/domain/connection_settings.dart';

class MemoryCredentials implements CredentialStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Map<String, dynamic> data({String id = 'a', bool expired = false}) => {
  'user': {
    'id': id,
    'username': 'user_$id',
    'email': '$id@example.test',
    'legacy_owner': id == 'a',
  },
  'access_token': 'access_$id',
  'refresh_token': 'refresh_$id',
  'expires_at': DateTime.now()
      .add(Duration(minutes: expired ? -5 : 15))
      .toIso8601String(),
};
const environment = BackendEnvironment(BackendMode.prod, 'https://server.test');
void main() {
  test(
    'password length counts Unicode characters consistently with the API',
    () {
      expect(AuthValidation.password('🥾🥾🥾🥾'), isNotNull);
      expect(AuthValidation.password('🥾🥾🥾🥾🥾🥾🥾🥾'), isNull);
      expect(AuthValidation.password('a' * 129), isNotNull);
    },
  );
  test(
    'invalid production configuration refuses login before networking',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      for (final url in ['', 'http://192.168.1.10:8080']) {
        final server = ServerConnection(
          client,
          environment: BackendEnvironment(BackendMode.prod, url),
          credentials: MemoryCredentials(),
        );
        await expectLater(server.login('a', 'test-password'), throwsStateError);
        expect(server.session, isNull);
      }
      expect(calls, 0);
    },
  );

  test('without session protected requests never reach network', () async {
    var calls = 0;
    final s = ServerConnection(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      environment: environment,
      credentials: MemoryCredentials(),
    );
    await s.restore();
    expect(s.session, isNull);
    await expectLater(s.request('/api/trails'), throwsStateError);
    expect(calls, 0);
  });
  test('expired cached session restores offline; outage preserves auth, logout removes it', () async {
    final store = MemoryCredentials();
    final online = ServerConnection(
      MockClient(
        (_) async => http.Response(jsonEncode(data(expired: true)), 200),
      ),
      environment: environment,
      credentials: store,
    );
    await online.login('a', 'test-password');
    var calls = 0;
    final offline = ServerConnection(
      MockClient((_) async {
        calls++;
        throw const SocketException('offline');
      }),
      environment: environment,
      credentials: store,
    );
    final auth = AuthController(offline, environment);
    await auth.restore();
    expect(auth.session?.user.id, 'a');
    expect(calls, 0);
    await expectLater(
      offline.request('/api/trails'),
      throwsA(isA<SocketException>()),
    );
    expect(auth.session?.user.id, 'a');
    expect(store.values.values.single, isNot(contains('test-password')));
    await auth.logout();
    expect(auth.session, isNull);
    await offline.restore();
    expect(offline.session, isNull);
    await auth.dispose();
  });
  test(
    'refresh rejection revokes session but transient503 retains offline access',
    () async {
      for (final status in [401, 503]) {
        var logged = false;
        final s = ServerConnection(
          MockClient((_) async {
            if (!logged) {
              logged = true;
              return http.Response(jsonEncode(data(expired: true)), 200);
            }
            return http.Response('{"error":"Unavailable"}', status);
          }),
          environment: environment,
          credentials: MemoryCredentials(),
        );
        await s.login('a', 'test-password');
        await expectLater(s.request('/api/trails'), throwsA(isA<ApiFailure>()));
        expect(s.session == null, status == 401);
      }
    },
  );
  test(
    'refresh rotation retries protected request and refuses redirects',
    () async {
      var calls = 0;
      final s = ServerConnection(
        MockClient((r) async {
          expect(r.followRedirects, false);
          calls++;
          if (r.url.path.endsWith('/login')) {
            return http.Response(jsonEncode(data()), 200);
          }
          if (r.url.path.endsWith('/refresh')) {
            return http.Response(
              jsonEncode({...data(), 'access_token': 'rotated'}),
              200,
            );
          }
          if (r.headers['Authorization'] == 'Bearer access_a') {
            return http.Response('{}', 401);
          }
          expect(r.headers['Authorization'], 'Bearer rotated');
          return http.Response('[]', 200);
        }),
        environment: environment,
        credentials: MemoryCredentials(),
      );
      await s.login('a', 'test-password');
      expect(await s.request('/api/trails'), isEmpty);
      expect(calls, 4);
    },
  );
  test('delayed old401 never retries a previous account mutation with new credentials', () async {
    var account = 'a';
    final delayed = Completer<http.Response>();
    var mutations = 0, refreshes = 0;
    final s = ServerConnection(
      MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return http.Response(jsonEncode(data(id: account)), 200);
        }
        if (r.url.path.endsWith('/sync')) {
          mutations++;
          expect(r.headers['Authorization'], 'Bearer access_a');
          return delayed.future;
        }
        if (r.url.path.endsWith('/refresh')) refreshes++;
        return http.Response('{}', 200);
      }),
      environment: environment,
      credentials: MemoryCredentials(),
    );
    await s.login('a', 'test-password');
    final old = s.bindAccount();
    final request = old.request('/api/sync', body: {'private': 'a'});
    final expectation = expectLater(request, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await s.logout();
    account = 'b';
    await s.login('b', 'test-password');
    delayed.complete(http.Response('{}', 401));
    await expectation;
    expect(mutations, 1);
    expect(refreshes, 0);
    await expectLater(old.request('/api/trails'), throwsStateError);
  });
  test(
    'session origin and environment isolation ignores legacy global token',
    () async {
      final store = MemoryCredentials()..values['token'] = 'old-key';
      final client = MockClient(
        (_) async => http.Response(jsonEncode(data()), 200),
      );
      final s = ServerConnection(
        client,
        environment: environment,
        credentials: store,
      );
      await s.login('a', 'test-password');
      for (final env in [
        const BackendEnvironment(BackendMode.dev, 'https://server.test'),
        const BackendEnvironment(BackendMode.prod, 'https://other.test'),
      ]) {
        final other = ServerConnection(
          client,
          environment: env,
          credentials: store,
        );
        await other.restore();
        expect(other.session, isNull);
      }
      final reopened = ServerConnection(
        client,
        environment: environment,
        credentials: store,
      );
      await reopened.restore();
      expect(reopened.session?.user.id, 'a');
    },
  );
  test('legacy library is claimed once by designated owner, across origin and account', () async {
    final dir = await Directory.systemTemp.createTemp('gpix-account');
    try {
      final old = File('${dir.path}/gpix.sqlite');
      await old.writeAsString('preserved');
      const owner = AuthUser(
            id: 'a',
            username: 'owner',
            email: 'a@example.test',
            legacyOwner: true,
          ),
          stranger = AuthUser(
            id: 'b',
            username: 'other',
            email: 'b@example.test',
          );
      final b = await AccountStorage.resolve(dir, 'prod:origin', stranger);
      expect(b.databasePath, isNot(old.path));
      await expectLater(
        AccountStorage.resolve(dir, 'prod:untrusted', owner),
        throwsA(isA<LegacyLibraryConsentRequired>()),
      );
      expect(
        await File('${dir.path}/legacy-library-owner.json').exists(),
        false,
      );
      await AccountStorage.decideLegacyImport(
        dir,
        'prod:untrusted',
        owner,
        false,
      );
      expect(
        (await AccountStorage.resolve(
          dir,
          'prod:untrusted',
          owner,
        )).databasePath,
        isNot(old.path),
      );
      await expectLater(
        AccountStorage.resolve(dir, 'prod:origin', owner),
        throwsA(isA<LegacyLibraryConsentRequired>()),
      );
      await AccountStorage.decideLegacyImport(dir, 'prod:origin', owner, true);
      final a = await AccountStorage.resolve(dir, 'prod:origin', owner);
      expect(a.databasePath, old.path);
      expect(a.mapsDirectory.path, '${dir.path}/maps');
      expect(
        (await AccountStorage.resolve(
          dir,
          'prod:elsewhere',
          owner,
        )).databasePath,
        isNot(old.path),
      );
      expect(
        (await AccountStorage.resolve(dir, 'prod:origin', owner)).databasePath,
        old.path,
      );
      expect(await old.readAsString(), 'preserved');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
