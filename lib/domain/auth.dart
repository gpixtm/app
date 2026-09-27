import 'app_message.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.legacyOwner = false,
  });
  final String id, username, email;
  final bool legacyOwner;
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'].toString(),
    username: j['username'],
    email: j['email'],
    legacyOwner: j['legacy_owner'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'legacy_owner': legacyOwner,
  };
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  final AuthUser user;
  final String accessToken, refreshToken;
  final DateTime expiresAt;
  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
    user: AuthUser.fromJson(j['user']),
    accessToken: j['access_token'],
    refreshToken: j['refresh_token'],
    expiresAt: DateTime.parse(j['expires_at']),
  );
  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toIso8601String(),
  };
}

abstract interface class AuthService {
  AuthSession? get session;
  Stream<void> get changes;
  Future<void> restore();
  Future<void> login(String identifier, String password);
  Future<void> register(String username, String email, String password);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String password);
  Future<void> changePassword(String current, String password);
  Future<void> logout();
}

class AuthValidation {
  static AppMessage? username(String? value) =>
      RegExp(r'^[A-Za-z0-9_]{3,32}$').hasMatch(value ?? '')
      ? null
      : AppMessage.invalidUsername;
  static AppMessage? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value ?? '')
      ? null
      : AppMessage.invalidEmail;
  static AppMessage? password(String? value) =>
      (value?.runes.length ?? 0) >= 8 && (value?.runes.length ?? 0) <= 128
      ? null
      : AppMessage.invalidPassword;
}

class LegacyLibraryConsentRequired implements Exception {
  const LegacyLibraryConsentRequired();
}
