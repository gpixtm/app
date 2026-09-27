import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/backend_environment.dart';
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

void main() {
  test(
    'production requires a real HTTPS configuration, not a fallback URL',
    () {
      for (final url in [
        '',
        'http://192.168.1.10:8080',
        'https://localhost',
        'https://user:pass@server.test',
        'https://server.test?token=x',
        'ftp://server.test',
      ]) {
        expect(
          BackendEnvironment(BackendMode.prod, url).problem,
          isNotNull,
          reason: url,
        );
      }
      expect(
        const BackendEnvironment(
          BackendMode.prod,
          'https://server.test/api-root/',
        ).problem,
        isNull,
      );
    },
  );

  test(
    'development HTTP is limited to private IPv4, including physical LAN',
    () {
      for (final ip in [
        '10.1.2.3',
        '172.16.0.1',
        '172.31.255.254',
        '192.168.1.10',
      ]) {
        expect(
          BackendEnvironment(BackendMode.dev, 'http://$ip:8080').problem,
          isNull,
        );
      }
      for (final ip in [
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '8.8.8.8',
        '172.32.0.1',
        '192.168.1.999',
        '192.168.001.2',
        'pc.local',
      ]) {
        expect(
          BackendEnvironment(BackendMode.dev, 'http://$ip:8080').problem,
          isNotNull,
          reason: ip,
        );
      }
    },
  );

  test('local map HTTP is restricted to the configured dev server; Prod always HTTPS', () {
    const dev = BackendEnvironment(BackendMode.dev, 'http://192.168.1.10:8080');
    expect(
      dev.permitsResource(
        Uri.parse('http://192.168.1.10:8080/api/packages/test.zip'),
      ),
      isTrue,
    );
    expect(
      dev.permitsResource(Uri.parse('http://192.168.1.11:8080/test.zip')),
      isFalse,
    );
    expect(
      dev.permitsResource(Uri.parse('http://192.168.1.10:8081/test.zip')),
      isFalse,
    );
    expect(
      dev.permitsResource(Uri.parse('https://maps.test/test.zip')),
      isTrue,
    );
    expect(
      const BackendEnvironment(
        BackendMode.prod,
        'https://server.test',
      ).permitsResource(Uri.parse('http://192.168.1.10/test.zip')),
      isFalse,
    );
  });

  test('exactly two mobile VS Code profiles point at the real app and matching flavor', () {
    final root = Directory.current;
    final launch = jsonDecode(
      File('${root.path}/.vscode/launch.json').readAsStringSync(),
    );
    final profiles = launch['configurations'] as List;
    expect(profiles.map((p) => p['name']), [
      'Gpix · Local Dev (Docker)',
      'Gpix · Prod',
    ]);
    for (var i = 0; i < profiles.length; i++) {
      final p = profiles[i], flavor = ['dev', 'prod'][i];
      expect(p['flutterMode'], 'debug');
      expect(p['type'], 'dart');
      expect(p['request'], 'launch');
      expect(
        Directory(
          (p['cwd'] as String).replaceAll(r'${workspaceFolder}', root.path),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          (p['program'] as String).replaceAll(r'${workspaceFolder}', root.path),
        ).existsSync(),
        isTrue,
      );
      expect(
        (p['toolArgs'] as List).where(
          (arg) => !(arg as String).startsWith('--dart-define=AUTH_PREFILL_'),
        ),
        [
          '--flavor',
          flavor,
          '--dart-define-from-file=\${workspaceFolder}/config/$flavor.local.json',
        ],
      );
    }
    for (final profile in profiles) {
      expect(
        (profile['toolArgs'] as List).any(
          (arg) => arg.toString().contains('AUTH_PREFILL_PASSWORD'),
        ),
        isFalse,
      );
    }
  });
}
