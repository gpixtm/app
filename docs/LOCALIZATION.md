# Localization workflow

Use the official [Flutter localization workflow](https://docs.flutter.dev/ui/internationalization): `flutter_localizations`, `intl`, ARB resources and `flutter gen-l10n`. English and French are both required.

## Adding a feature

1. Add meaningful English keys to `lib/l10n/app_en.arb` and translate every key in `app_fr.arb`. Put whole sentences in resources, with typed placeholders and ICU plural rules rather than concatenated translated fragments. Use `intl` for dates and numbers.
2. Run `flutter gen-l10n`, then `dart tool/generate_message_resolver.dart`, then format generated/changed Dart files. Generated Flutter getters live in `lib/l10n/generated/`; edit the ARB sources, never generated translations.
3. In widgets use `context.l10n`. In pure Dart business/application code, carry an `AppMessage` code and arguments; resolve with `context.message` when rendering. Preserve error objects rather than converting them to strings before display. The generated resolver adapts codes to standard Flutter getters; it is not a second translation dictionary.
4. Add native Android text to both `android/app/src/main/res/values/strings.xml` and `values-fr/strings.xml`. Native privacy screens use the saved locale. Foreground GPS notification content is selected when the recording stream starts; an already running notification updates on the next stream start.
5. Test both languages, switching, plural cases and any changed dialogs/validation. Unknown remote codes produce a localized generic error; raw server diagnostics are not user-facing translations. API errors include stable English `code` values and English diagnostic `error` text.

## Preference and boundaries

The selector is available on every authentication page and in signed-in Settings. It offers device language, English and French. Unsupported device languages fall back to English. The selected preference is stored on the device independently of account sessions, survives offline restart and sign-out, and also selects routing/email language. Form contents and active navigation state must survive a locale change.

User GPX names, descriptions, place names and imported health sources remain unchanged. Localization tests may deliberately contain French and other Unicode text. Generated names use localized naming callbacks at creation; existing saved user content is never renamed when the locale changes.

API approach requests carry a language and caches separate languages. Previously downloaded provider directions remain provider content; changing language does not manufacture an offline translation. A newly calculated approach uses the selected language.

Run `flutter analyze`, `flutter test` and the affected native build. The localization suite checks catalog parity, language switching, saved preference and locale-independent notices. New features must extend localization alongside implementation rather than deferring it.
