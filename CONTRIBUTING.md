# Contributing to Gpix

Thanks for your interest! Bug reports, translations, fixes and features are welcome. For a large change, open an issue first so we can agree on the approach; [docs/PRODUCT.md](docs/PRODUCT.md) records the product decisions a change must respect.

## Workflow

1. Fork the repository and branch from `develop` (`main` holds released versions).
2. Set up the pinned SDK and a server as described in the [README](README.md#build-from-source) and [docs/DEBUG-VSCODE.md](docs/DEBUG-VSCODE.md).
3. Make focused commits with [Conventional Commits](https://www.conventionalcommits.org/) messages: `feat: …`, `fix: …`, `docs: …`, `refactor: …`, `test: …`.
4. Run the checks below, then open a pull request against `develop` describing the behaviour change and how you tested it (automated tests, emulator, real phone). CI runs the same checks.

Enable the repository's commit hooks once per clone:

```sh
git config core.hooksPath .githooks
```

## Checks

```sh
puro flutter gen-l10n
puro dart tool/generate_message_resolver.dart
puro dart format lib test tool
puro flutter analyze
puro flutter test
```

Changes to Android manifests, permissions, plugins or Kotlin code need a full rebuild and a check on a device or emulator; hot reload is not enough. Say in the PR what you could not verify (a real walk, screen-off behaviour, a watch…).

## Rules

- **English in code**: identifiers, comments, tests, docs and diagnostics.
- **Every user-visible text is localized** in English (`lib/l10n/app_en.arb`, the template) and French (`app_fr.arb`), including errors, tooltips, accessibility labels and notifications. Native Android strings go in `values/` and `values-fr/`. Read [docs/LOCALIZATION.md](docs/LOCALIZATION.md). New languages are welcome.
- **Layers**: `lib/domain` is pure Dart (no Flutter, plugins or I/O); `lib/application` orchestrates through ports; storage, HTTP and platform code belong in `lib/data`; widgets in `lib/presentation`. Reuse `TrailGeometry` and the shared distance axis rather than re-implementing geometry.
- **Data safety**: every local change is written with its outbox operation in one transaction; migrations keep existing data and come with an upgrade test. Missing measurements stay absent rather than becoming zeroes.
- **Shared trail fingerprint**: `lib/domain/trail_identity.dart` and `lib/data/trail_identity_hash.dart` must stay byte-identical to the API's `TrailFingerprint`; change both repositories together.
- **User data** (GPX names, descriptions, places) keeps its original bytes: preserve accents, emoji and non-Latin scripts.
- **Dependencies**: keep `pubspec.lock` changes to what your PR needs.
- **No secrets or private data** in commits: `config/*.local.json`, `android/key.properties`, keystores, personal GPX files, databases and server addresses stay local.

## Licence

By contributing, you agree that your contributions are licensed under the [GPL-3.0](LICENSE).
