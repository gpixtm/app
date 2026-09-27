import '../domain/app_message.dart';

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../application/backend_environment.dart';
import '../domain/auth.dart';
import '../domain/connection_settings.dart';
import '../domain/sync.dart';
import 'trail_codec.dart';

class ServerConnection implements AuthService {
  ServerConnection(
    this.client, {
    required this.environment,
    required this.credentials,
    this.languageCode,
  });
  final http.Client client;
  final BackendEnvironment environment;
  final CredentialStore credentials;
  final String Function()? languageCode;
  AuthSession? _session;
  int _generation = 0;
  Future<void>? _refreshing;
  final _changes = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => _changes.stream;
  @override
  AuthSession? get session => _session;
  String get base => environment.normalizedUrl;
  String get scope =>
      '${environment.mode.name}:${sha256.convert(utf8.encode(base))}';
  String get _key => 'gpix.session.$scope';
  ConnectionDetails get details => ConnectionDetails(
    environment: environment.label,
    url: base,
    problem: environment.problem,
  );
  @override
  Future<void> restore() async {
    if (environment.problem != null) return;
    final stored = await credentials.read(_key);
    if (stored == null || stored.isEmpty) return;
    try {
      _session = AuthSession.fromJson(jsonDecode(stored));
    } catch (_) {
      await credentials.write(_key, '');
    }
    _changes.add(null);
  }

  Future<void> _persistence = Future.value();
  Future<void> _save(AuthSession? value, int generation) {
    if (value == null && generation == _generation) {
      _session = null;
      _changes.add(null);
    }
    final pending = _persistence.then((_) async {
      if (generation != _generation) return;
      await credentials.write(
        _key,
        value == null ? '' : jsonEncode(value.toJson()),
      );
      if (generation != _generation) return;
      _session = value;
      _changes.add(null);
    });
    _persistence = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  void _check(int generation) {
    if (generation != _generation || _session == null) {
      throw MessageFailure(AppMessage.sessionChanged);
    }
  }

  Future<dynamic> _send(String path, {Object? body, String? access}) async {
    environment.requireEndpoint();
    final req =
        http.Request(body == null ? 'GET' : 'POST', Uri.parse('$base$path'))
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json; charset=utf-8';
    req.headers['Accept-Language'] = languageCode?.call() ?? 'en';
    if (access != null) req.headers['Authorization'] = 'Bearer $access';
    if (body != null) req.body = jsonEncode(body);
    final response = await client
        .send(req)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 25));
    dynamic data;
    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(
        response.statusCode,
        data is Map && data['code'] is String
            ? AppMessage(data['code'] as String)
            : switch (response.statusCode) {
                401 => AppMessage(
                  path == '/api/auth/login'
                      ? 'invalidCredentials'
                      : 'sessionExpired',
                ),
                422 => const AppMessage('invalidRequest'),
                429 => const AppMessage('rateLimited'),
                _ => AppMessage.serverUnavailable(response.statusCode),
              },
        diagnostic: data is Map && data['error'] is String
            ? data['error'] as String
            : null,
      );
    }
    return data;
  }

  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    final generation = ++_generation;
    final result = AuthSession.fromJson(await _send(path, body: body));
    if (generation == _generation) await _save(result, generation);
  }

  @override
  Future<void> login(String identifier, String password) => _authenticate(
    '/api/auth/login',
    {'identifier': identifier, 'password': password},
  );
  @override
  Future<void> register(String username, String email, String password) =>
      _authenticate('/api/auth/register', {
        'username': username,
        'email': email,
        'password': password,
      });
  @override
  Future<void> forgotPassword(String email) async {
    await _send('/api/auth/forgot-password', body: {'email': email});
  }

  @override
  Future<void> resetPassword(String token, String password) async {
    await _send(
      '/api/auth/reset-password',
      body: {'token': token, 'password': password},
    );
  }

  @override
  Future<void> changePassword(String current, String password) async {
    await request(
      '/api/auth/change-password',
      body: {'current_password': current, 'password': password},
    );
    await logout();
  }

  Future<void> _refresh() async {
    if (_refreshing != null) return _refreshing!;
    final operation = _doRefresh();
    _refreshing = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshing, operation)) _refreshing = null;
    }
  }

  Future<void> _doRefresh() async {
    final previous = _session;
    if (previous == null) throw MessageFailure(AppMessage.signInRequired);
    final generation = _generation;
    try {
      final renewed = AuthSession.fromJson(
        await _send(
          '/api/auth/refresh',
          body: {'refresh_token': previous.refreshToken},
        ),
      );
      if (generation != _generation || _session?.user.id != previous.user.id) {
        throw MessageFailure(AppMessage.sessionChanged);
      }
      await _save(renewed, generation);
    } on ApiFailure catch (e) {
      if ((e.status == 401 || e.status == 403) && generation == _generation) {
        ++_generation;
        await _save(null, _generation);
      }
      rethrow;
    }
  }

  Future<String> accessToken() async {
    if (_session == null) throw MessageFailure(AppMessage.signInRequired);
    if (!_session!.expiresAt.isAfter(
      DateTime.now().add(const Duration(seconds: 30)),
    )) {
      await _refresh();
    }
    if (_session == null) {
      throw MessageFailure(AppMessage.sessionExpired);
    }
    return _session!.accessToken;
  }

  ServerConnection bindAccount() => _AccountConnection(this, _generation);
  Future<dynamic> request(String path, {Object? body}) async {
    final generation = _generation;
    var access = await accessToken();
    _check(generation);
    try {
      final result = await _send(path, body: body, access: access);
      _check(generation);
      return result;
    } on ApiFailure catch (e) {
      _check(generation);
      if (e.status != 401) rethrow;
      await _refresh();
      _check(generation);
      access = await accessToken();
      _check(generation);
      try {
        final result = await _send(path, body: body, access: access);
        _check(generation);
        return result;
      } on ApiFailure catch (retryError) {
        _check(generation);
        if (retryError.status == 401) {
          ++_generation;
          await _save(null, _generation);
        }
        rethrow;
      }
    }
  }

  Future<http.StreamedResponse> download(
    Uri uri,
    http.Client downloadClient,
  ) async {
    final generation = _generation;
    _check(generation);
    if (!environment.permitsResource(uri)) {
      throw MessageFailure(AppMessage.mapAddressRejected);
    }
    final own = uri.origin == Uri.parse(base).origin;
    Future<http.StreamedResponse> send() async {
      final req = http.Request('GET', uri)..followRedirects = false;
      if (own) req.headers['Authorization'] = 'Bearer ${await accessToken()}';
      _check(generation);
      return downloadClient.send(req).timeout(const Duration(seconds: 30));
    }

    var response = await send();
    _check(generation);
    if (own && response.statusCode == 401) {
      await response.stream.drain<void>();
      _check(generation);
      await _refresh();
      _check(generation);
      response = await send();
      _check(generation);
    }
    return http.StreamedResponse(
      response.stream.map((chunk) {
        _check(generation);
        return chunk;
      }),
      response.statusCode,
      contentLength: response.contentLength,
      headers: response.headers,
      request: response.request,
    );
  }

  @override
  Future<void> logout() async {
    final old = _session;
    ++_generation;
    await _save(null, _generation);
    if (old != null) {
      try {
        await _send(
          '/api/auth/logout',
          body: {'refresh_token': old.refreshToken},
          access: old.accessToken,
        );
      } catch (_) {
        /* Local logout always succeeds, including offline. */
      }
    }
  }
}

class ApiFailure extends RemoteFailure {
  ApiFailure(super.status, super.message, {this.diagnostic});
  final String? diagnostic;
}

class ApiSyncTransport implements SyncTransport {
  ApiSyncTransport(this.server);
  final ServerConnection server;
  @override
  Future<SyncResult> push(SyncOperation op) async {
    final r = await server.request(
      '/api/sync',
      body: {
        'id': op.id,
        'mutation': op.operationId,
        'baseRevision': op.revision,
        'deleted': op.deleted,
        'payload': TrailCodec.encode(op.trail),
      },
    );
    return SyncResult(r['revision'], r['conflict']);
  }

  @override
  Future<List<SyncOperation>> pull() async =>
      ((await server.request('/api/trails')) as List)
          .map(
            (r) => SyncOperation(
              r['id'],
              r['mutation'],
              r['revision'],
              r['deleted'],
              TrailCodec.decode(r['payload']),
            ),
          )
          .toList();
}

// A library can never acquire a later account's credentials while a sync is pending.
class _AccountConnection extends ServerConnection {
  _AccountConnection(this.parent, this.generation)
    : super(
        parent.client,
        environment: parent.environment,
        credentials: parent.credentials,
      );
  final ServerConnection parent;
  final int generation;
  void check() {
    if (parent._generation != generation || parent.session == null) {
      throw MessageFailure(AppMessage.sessionChanged);
    }
  }

  @override
  Future<dynamic> request(String path, {Object? body}) async {
    check();
    final r = await parent.request(path, body: body);
    check();
    return r;
  }

  @override
  Future<http.StreamedResponse> download(Uri uri, http.Client client) async {
    check();
    final r = await parent.download(uri, client);
    check();
    return http.StreamedResponse(
      r.stream.map((chunk) {
        check();
        return chunk;
      }),
      r.statusCode,
      contentLength: r.contentLength,
      headers: r.headers,
      request: r.request,
    );
  }
}
