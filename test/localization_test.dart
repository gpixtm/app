import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/auth_controller.dart';
import 'package:gpix/application/backend_environment.dart';
import 'package:gpix/presentation/auth.dart';
import 'package:gpix/presentation/localization.dart';
import 'package:gpix/presentation/settings.dart';

import 'auth_ui_test.dart' show FakeAuth;
import 'backend_environment_test.dart' show MemoryCredentials;
import 'lifecycle_test.dart' show controller;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production source keeps French in resources and visible literals out of widgets', () {
    final violations = <String>[];
    final french = RegExp('[éèêàçùôîÉÀœ]');
    final inlineText = RegExp(
      r'''\bText\(\s*(?:'([A-Za-z][^']*)'|"([A-Za-z][^"]*)")''',
    );
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.contains('/l10n/')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (french.hasMatch(source)) {
        violations.add('$path: French outside resources');
      }
      if (path.contains('/presentation/')) {
        for (final match in inlineText.allMatches(source)) {
          if ((match.group(1) ?? match.group(2)) != 'gpix') {
            violations.add('$path: inline visible text');
          }
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('catalogs have identical nonempty keys and translated plural forms', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final fr = jsonDecode(
      File('lib/l10n/app_fr.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final keys = en.keys.where((key) => !key.startsWith('@')).toSet();
    expect(fr.keys.where((key) => !key.startsWith('@')).toSet(), keys);
    for (final key in keys) {
      expect(en[key], isNotEmpty, reason: 'English $key');
      expect(fr[key], isNotEmpty, reason: 'French $key');
    }
    final english = lookupAppLocalizations(const Locale('en'));
    final french = lookupAppLocalizations(const Locale('fr'));
    expect(english.itemsSaved(1), 'One item saved on this phone');
    expect(english.itemsSaved(2), '2 items saved on this phone');
    expect(french.itemsSaved(1), 'Un élément enregistré sur ce téléphone');
    expect(french.itemCount(0), '0 éléments');
  });

  test(
    'locale preference survives restart without a session or network',
    () async {
      final store = MemoryCredentials();
      final first = LocaleController(store: store);
      await first.select('fr');
      first.dispose();
      final restored = LocaleController(store: store);
      await restored.load();
      expect(restored.locale, const Locale('fr'));
      await restored.select(null);
      restored.dispose();
      final system = LocaleController(store: store);
      await system.load();
      expect(system.locale, isNull);
      system.dispose();
    },
  );

  testWidgets(
    'auth language selector preserves input and retranslates existing API errors',
    (tester) async {
      final store = MemoryCredentials();
      final locale = LocaleController(
        store: store,
        initialLocale: const Locale('en'),
      );
      final service = FakeAuth();
      final auth = AuthController(
        service,
        const BackendEnvironment(BackendMode.dev, 'http://192.168.1.2:8080'),
      );
      await auth.restore();
      await tester.pumpWidget(
        AuthShell(
          auth: auth,
          localeController: locale,
          openLibrary: (_) => throw StateError('Unexpected library open'),
          closeLibrary: () async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'walker');
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect username or password.'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();

      expect(find.text('Se connecter'), findsOneWidget);
      expect(
        find.text('Identifiant ou mot de passe incorrect.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'walker',
      );
      expect(store.values['gpix.locale'], 'fr');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      addTearDown(auth.dispose);

      addTearDown(service.events.close);
      locale.dispose();
    },
  );

  testWidgets(
    'settings switches language and resolves stored sync state without mutating data',
    (tester) async {
      final app = controller();
      app.syncStatus = AppMessage.itemsSaved(2);
      final locale = LocaleController(initialLocale: const Locale('fr'));
      await tester.pumpWidget(
        LocalizedApp(
          controller: locale,
          homeBuilder: (_) => Scaffold(body: SettingsView(app, account: () {})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mes données'), findsOneWidget);
      expect(
        find.text('2 éléments enregistrés sur ce téléphone'),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(find.text('My data'), findsOneWidget);
      expect(find.text('2 items saved on this phone'), findsOneWidget);
      expect((app.syncStatus as AppMessage).arguments, [2]);
      await tester.pumpWidget(const SizedBox());
      await app.shutdown();
      locale.dispose();
    },
  );

  testWidgets(
    'unsupported device locale falls back to English and system French is honored',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('de')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        LocalizedApp(homeBuilder: (context) => Text(context.l10n.settings)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      tester.binding.platformDispatcher.localesTestValue = [const Locale('fr')];
      await tester.pumpAndSettle();

      expect(find.text('Réglages'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
