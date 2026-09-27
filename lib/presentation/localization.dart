import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../domain/app_message.dart';
import '../domain/connection_settings.dart';
import '../l10n/generated/app_localizations.dart';
import 'message_resolver.dart';

export '../domain/app_message.dart';
export '../l10n/generated/app_localizations.dart';

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String message(Object? value) {
    if (value is RemoteFailure) value = value.message;
    if (value is MessageFailure) value = value.detail;
    if (value is MessageFormatException) value = value.detail;
    if (value is FormatException) return l10n.invalidRequest;
    if (value is AppMessage) {
      return resolveAppMessage(l10n, value, (argument) {
        if (argument is num) {
          return NumberFormat.decimalPattern(l10n.localeName).format(argument);
        }
        if (argument is AppMessage ||
            argument is Exception ||
            argument is Error) {
          return message(argument);
        }
        return argument?.toString() ?? '';
      });
    }
    if (value is SocketException || value is TimeoutException) {
      return l10n.networkError;
    }
    if (value is PlatformException) {
      return value.code == 'permission'
          ? l10n.healthPermissionsMissing
          : l10n.unexpectedError;
    }
    return value is String ? value : l10n.unexpectedError;
  }

  String? validation(AppMessage? value) =>
      value == null ? null : message(value);
}

/// Device preference: available before sign-in and unchanged by account switches.
class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  LocaleController({this.store, this.applyNative, Locale? initialLocale})
    : _locale = initialLocale {
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_locale == null) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final CredentialStore? store;
  final Future<void> Function(String?)? applyNative;
  Locale? _locale;
  Locale? get locale => _locale;
  String get languageCode =>
      _locale?.languageCode ??
      basicLocaleListResolution(
        WidgetsBinding.instance.platformDispatcher.locales,
        AppLocalizations.supportedLocales,
      ).languageCode;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    final saved = await store?.read('gpix.locale');
    if (saved == 'fr' || saved == 'en') _locale = Locale(saved!);
    await applyNative?.call(_locale?.languageCode);
    notifyListeners();
  }

  Future<void> select(String? language) async {
    if (language != null && language != 'fr' && language != 'en') return;
    final next = language == null ? null : Locale(language);
    // Serialize persistence so a slow previous selection cannot overwrite the last one.
    final write = _writes.catchError((Object _) {}).then((_) async {
      await applyNative?.call(language);
      await store?.write('gpix.locale', language ?? '');
    });
    _writes = write;
    await write;
    _locale = next;
    notifyListeners();
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    required LocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}

class LocalizedApp extends StatefulWidget {
  const LocalizedApp({
    required this.homeBuilder,
    this.theme,
    this.controller,
    super.key,
  });
  final WidgetBuilder homeBuilder;
  final ThemeData? theme;
  final LocaleController? controller;
  @override
  State<LocalizedApp> createState() => _LocalizedAppState();
}

class _LocalizedAppState extends State<LocalizedApp> {
  late final LocaleController controller =
      widget.controller ?? LocaleController();
  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (_, _) {
        Intl.defaultLocale = controller.languageCode;
        return MaterialApp(
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          theme: widget.theme,
          home: Builder(builder: widget.homeBuilder),
        );
      },
    ),
  );
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    return DropdownButtonFormField<String>(
      key: ValueKey('language-${controller.locale?.languageCode ?? 'system'}'),
      initialValue: controller.locale?.languageCode ?? 'system',
      decoration: InputDecoration(
        labelText: context.l10n.language,
        prefixIcon: const Icon(Icons.language),
      ),
      items: [
        DropdownMenuItem(
          value: 'system',
          child: Text(context.l10n.systemLanguage),
        ),
        DropdownMenuItem(
          value: 'en',
          child: Text(context.l10n.englishLanguage),
        ),
        DropdownMenuItem(value: 'fr', child: Text(context.l10n.frenchLanguage)),
      ],
      onChanged: (value) async {
        try {
          await controller.select(value == 'system' ? null : value);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.message(error))));
          }
        }
      },
    );
  }
}
