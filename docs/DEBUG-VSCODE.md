# Development and Android debugging

Open this repository in VS Code. Install the Flutter/Dart extensions. In the full workspace the pinned SDK is `../.tooling/flutter`; for a standalone clone install the matching Flutter version and select it through VS Code's Flutter SDK command. Machine-specific `.vscode/settings.json` is ignored.

Copy `config/dev.example.json` and `config/prod.example.json` to the corresponding ignored `*.local.json` files. Set `API_URL` to your private LAN HTTP origin for Dev and an HTTPS origin for Prod. Optional Dev-only `AUTH_PREFILL_IDENTIFIER` / `AUTH_PREFILL_PASSWORD` can be placed in the ignored Dev JSON; never commit them. Prod has no prefill values.

The two launch profiles use `lib/main.dart` and the matching `dev`/`prod` flavor. Both are debug builds: Prod is a server selection, not a release signature. Changing compile-time values requires stopping and restarting F5.

## API over the LAN

Clone `gpixtm/api` separately. In the full workspace it is the sibling `backend/`; its `make dev` or `dart tools/dev_backend.dart` prepares Docker on the explicit private IPv4 interface from the mobile configuration. See that repository's instructions before installing or changing the API. A standalone app clone can use any compatible separately running API.

Phone and computer must share the LAN. Use a normal private address without tunnels or `adb reverse`. `localhost` on a phone means the phone, and `10.0.2.2` is emulator-specific. Check `/health` from the phone. Docker Desktop can prevent the computer reaching its own published LAN address while the phone succeeds. `make up`, `make mailpit` and `make dev-off` restore loopback; run `make dev` again for a physical phone. The Dev launch profile runs `tool/start_dev_api.dart` before F5. It starts the sibling API when available; in a standalone clone it leaves API startup to your separately configured server.

Production uses HTTPS and real accounts. Never disable certificate validation or run fixtures against production. Read the API repository's `AGENTS.md` before touching its production endpoint, configuration or deployment.

## Validate and build

Use `flutter`/`dart` below, or their pinned full-workspace paths (`../.tooling/flutter/bin/flutter.bat` and `dart.bat` on Windows).

```sh
flutter pub get
flutter gen-l10n
dart tool/generate_message_resolver.dart
dart format lib test tool
flutter analyze
flutter test
flutter build apk --debug --target=lib/main.dart --flavor dev --dart-define-from-file=config/dev.local.json --target-platform android-arm64 --split-per-abi
flutter build apk --debug --target=lib/main.dart --flavor prod --dart-define-from-file=config/prod.local.json --target-platform android-arm64 --split-per-abi
```

Integration tests requiring a live API must be configured explicitly; a skipped integration test is not a server validation. `tool/*_smoke.dart` entry points are test harnesses and must never replace the real app in a delivery. Use a full restart after native changes. Personal-device installation requires a user request.

Read [AGENTS.md](../AGENTS.md) before development and follow its commit/merge approval sequence. Keep user data, local configurations, build outputs, signing keys and credentials out of Git.
