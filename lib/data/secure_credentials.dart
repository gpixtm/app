import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/connection_settings.dart';

class SecureCredentials implements CredentialStore {
  const SecureCredentials();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
