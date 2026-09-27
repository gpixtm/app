class ConnectionDetails {
  const ConnectionDetails({
    required this.environment,
    required this.url,
    this.problem,
  });
  final String environment, url;
  final Object? problem;
}

abstract interface class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
