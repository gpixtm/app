import '../domain/app_message.dart';

import 'dart:async';

import '../domain/auth.dart';
import 'backend_environment.dart';
export '../domain/auth.dart';

class AuthController {
  AuthController(this.service, this.environment) {
    _subscription = service.changes.listen((_) => _notify());
  }
  final AuthService service;
  final BackendEnvironment environment;
  late final StreamSubscription<void> _subscription;
  final changes = StreamController<void>.broadcast();
  AuthSession? get session => service.session;
  bool restoring = true, busy = false;
  Object? message;
  void _notify() {
    if (!changes.isClosed) changes.add(null);
  }

  Future<void> restore() async {
    try {
      await service.restore();
    } catch (_) {
      message = AppMessage.sessionRestoreFailed;
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    message = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      message = e;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> login(String identifier, String password) =>
      _run(() => service.login(identifier.trim(), password));
  Future<bool> register(String username, String email, String password) =>
      _run(() => service.register(username.trim(), email.trim(), password));
  Future<bool> forgotPassword(String email) =>
      _run(() => service.forgotPassword(email.trim()));
  Future<bool> resetPassword(String token, String password) =>
      _run(() => service.resetPassword(_resetToken(token), password));
  String _resetToken(String value) {
    final text = value.trim();
    final uri = Uri.tryParse(text);
    return uri?.scheme == 'gpix' && uri?.host == 'reset-password'
        ? (uri?.queryParameters['token'] ?? text)
        : text;
  }

  Future<bool> changePassword(String current, String password) =>
      _run(() => service.changePassword(current, password));
  Future<bool> logout() => _run(service.logout);
  Future<void> dispose() async {
    await _subscription.cancel();
    await changes.close();
  }
}
