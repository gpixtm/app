import 'package:gpix/presentation/localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/auth_controller.dart';
import 'package:gpix/application/backend_environment.dart';
import 'package:gpix/presentation/auth.dart';
import 'package:gpix/presentation/design.dart';

class FakeAuth implements AuthService {
  final events = StreamController<void>.broadcast();
  int logins = 0, resets = 0, registrations = 0;
  String? lastIdentifier;
  @override
  AuthSession? session;
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<void> restore() async {}
  @override
  Future<void> login(String identifier, String password) async {
    logins++;
    lastIdentifier = identifier;
    throw MessageFailure(const AppMessage('invalidCredentials'));
  }

  @override
  Future<void> register(String username, String email, String password) async {
    registrations++;
  }

  @override
  Future<void> forgotPassword(String email) async {}
  @override
  Future<void> resetPassword(String token, String password) async {
    resets++;
  }

  @override
  Future<void> changePassword(String current, String password) async {}
  @override
  Future<void> logout() async {
    session = null;
    events.add(null);
  }
}

void main() {
  late FakeAuth service;
  late AuthController auth;
  setUp(() async {
    service = FakeAuth();
    auth = AuthController(
      service,
      const BackendEnvironment(BackendMode.dev, 'http://192.168.1.10:8080'),
    );
    await auth.restore();
  });
  tearDown(() async {
    await auth.dispose();
    await service.events.close();
  });
  testWidgets('login prefill never carries credentials into registration', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedApp(
        theme: appTheme(),
        homeBuilder: (context) => AuthScreen(
          auth: auth,
          initialIdentifier: 'prefilled-login',
          initialPassword: 'fixture-password',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'prefilled-login',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'fixture-password',
    );
    await tester.ensureVisible(find.text("Create an account"));
    await tester.tap(find.text("Create an account"));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }
  });
  testWidgets(
    'legacy library requires a deliberate account association choice',
    (tester) async {
      service.session = AuthSession(
        user: const AuthUser(
          id: 'owner',
          username: 'alice',
          email: 'alice@example.test',
          legacyOwner: true,
        ),
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: DateTime(2020),
      );
      final decisions = <bool>[];
      var opens = 0;
      await tester.pumpWidget(
        AuthShell(
          auth: auth,
          openLibrary: (_) async {
            opens++;
            throw const LegacyLibraryConsentRequired();
          },
          closeLibrary: () async {},
          decideLegacyImport: (_, adopt) async {
            decisions.add(adopt);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Your previous library"), findsOneWidget);
      expect(find.textContaining('alice on this server'), findsOneWidget);
      expect(decisions, isEmpty);
      expect(opens, 1);
      await tester.ensureVisible(find.text("Use a separate library"));
      await tester.tap(find.text("Use a separate library"));
      await tester.pumpAndSettle();
      expect(decisions, [false]);
      expect(opens, 2);
      expect(find.text("My trails"), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      LocalizedApp(
        theme: appTheme(),
        homeBuilder: (context) => AuthScreen(auth: auth),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('anonymous guard never opens the library and validates login', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      AuthShell(
        auth: auth,
        openLibrary: (_) async {
          opened++;
          throw StateError('Unexpected');
        },
        closeLibrary: () async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Sign in"), findsOneWidget);
    expect(find.text("My trails"), findsNothing);
    await tester.ensureVisible(find.text("Sign in"));
    await tester.tap(find.text("Sign in"));
    await tester.pumpAndSettle();
    expect(service.logins, 0);
    expect(opened, 0);
    expect(find.text("This field is required."), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'login submits identifier and displays errors without losing form',
    (tester) async {
      await show(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'alice@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrong-password',
      );
      await tester.tap(find.byTooltip("Show password"));
      expect(find.byTooltip("Hide password"), findsNothing);
      await tester.pump();
      expect(find.byTooltip("Hide password"), findsOneWidget);
      await tester.tap(find.text("Sign in"));
      await tester.pumpAndSettle();
      expect(service.lastIdentifier, 'alice@example.test');
      expect(find.text('Incorrect username or password.'), findsOneWidget);
    },
  );
  testWidgets('registration requires matching passwords before sending', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text("Create an account"));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alice');
    await tester.enterText(fields.at(1), 'alice@example.test');
    await tester.enterText(fields.at(2), 'abcdefgh');
    await tester.enterText(fields.at(3), 'different');
    await tester.ensureVisible(find.text("Create my account"));
    await tester.tap(find.text("Create my account"));
    await tester.pumpAndSettle();
    expect(service.registrations, 0);
    expect(find.text("Passwords do not match."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reset code workflow confirms success and returns to login', (
    tester,
  ) async {
    await show(tester);
    await tester.ensureVisible(find.text("I have a reset code"));
    await tester.tap(find.text("I have a reset code"));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'temporary-test-code');
    await tester.enterText(fields.at(1), 'new-password');
    await tester.enterText(fields.at(2), 'new-password');
    await tester.ensureVisible(find.text("Save password"));
    await tester.tap(find.text("Save password"));
    await tester.pumpAndSettle();
    expect(service.resets, 1);
    expect(find.text("Sign in"), findsOneWidget);
    expect(find.textContaining('Password saved.'), findsOneWidget);
  });
  testWidgets('logout destroys previously pushed protected routes', (
    tester,
  ) async {
    service.session = AuthSession(
      user: const AuthUser(
        id: 'one',
        username: 'alice',
        email: 'alice@example.test',
      ),
      accessToken: 'test',
      refreshToken: 'test',
      expiresAt: DateTime(2020),
    );
    // Loading state is authenticated even when the offline token has expired.
    final pending = Completer<Never>();
    await tester.pumpWidget(
      AuthShell(
        auth: auth,
        openLibrary: (_) => pending.future,
        closeLibrary: () async {},
      ),
    );
    await tester.pump();
    expect(find.text("Sign in"), findsNothing);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AccountScreen(auth: auth, resolveConflicts: () async {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("My account"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("Sign out"),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text("Sign out"));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("My account"), findsNothing);
    expect(find.text("Sign in"), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    pending.completeError(StateError('test closed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
