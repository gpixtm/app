import '../domain/app_message.dart';

enum BackendMode { dev, prod }

/// Pure configuration policy, shared by the app and the local Docker launcher.
class BackendEnvironment {
  const BackendEnvironment(this.mode, this.apiUrl);
  final BackendMode mode;
  final String apiUrl;

  String get label => mode == BackendMode.dev ? "Local Dev (Docker)" : 'Prod';
  String get configFile => 'mobile/config/${mode.name}.local.json';
  String get normalizedUrl => apiUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  AppMessage? get problem {
    if (normalizedUrl.isEmpty) {
      return AppMessage.missingApiUrl(label, configFile);
    }
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      return AppMessage.invalidApiUrl(label, configFile);
    }
    if (uri.host == 'localhost' ||
        uri.host == '::1' ||
        uri.host.startsWith('127.')) {
      return AppMessage.localhostApiUrl(label, configFile);
    }
    if (uri.scheme == 'https') return null;
    if (mode == BackendMode.dev &&
        uri.scheme == 'http' &&
        isPrivateIpv4(uri.host)) {
      return null;
    }
    return mode == BackendMode.prod
        ? AppMessage.prodHttpsRequired(configFile)
        : AppMessage.devPrivateIpRequired;
  }

  Uri requireEndpoint() {
    final issue = problem;
    if (issue != null) throw MessageFailure(issue);
    return Uri.parse(normalizedUrl);
  }

  bool permitsResource(Uri uri) {
    if (uri.userInfo.isNotEmpty || !uri.hasAuthority) return false;
    if (uri.scheme == 'https') return true;
    return mode == BackendMode.dev &&
        problem == null &&
        uri.scheme == 'http' &&
        isPrivateIpv4(uri.host) &&
        uri.origin == requireEndpoint().origin;
  }

  static bool isPrivateIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final bytes = parts.map(int.tryParse).toList();
    if (bytes.any((v) => v == null || v < 0 || v > 255)) return false;
    if (List.generate(4, (i) => '${bytes[i]}').join('.') != host) return false;
    return bytes[0] == 10 ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 172 && bytes[1]! >= 16 && bytes[1]! <= 31);
  }
}
