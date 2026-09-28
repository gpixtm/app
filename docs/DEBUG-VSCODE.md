# Development and Android debugging

Open this repository in VS Code. Install the Flutter/Dart extensions and set up the Flutter SDK with Puro as described below. Machine-specific `.vscode/settings.json` is ignored.

## Flutter SDK (Puro)

The SDK is managed by [Puro](https://puro.dev) in a dedicated environment named `gpix`, pinned to Flutter **3.47.5** stable (framework `6a19cca564`, Dart 3.13.4). It is isolated from Puro's shared `stable` environment and from any `flutter` installed on `PATH`, so other projects are unaffected.

One-time setup, from the repository root:

```sh
puro create gpix 3.47.5
puro use gpix
```

`puro use` writes a local `.puro.json` (listed in `.git/info/exclude`, not committed) and points VS Code's `dart.flutterSdkPath` and `dart.sdkPath` at the environment in `.vscode/settings.json`. Restart VS Code afterwards. The next `puro flutter pub get` rewrites `flutter.sdk` in the ignored `android/local.properties`.

Check the active SDK with `puro flutter --version`. If `flutter` on `PATH` points to another installation, keep calling `puro flutter` / `puro dart` explicitly rather than the bare commands. Outside this repository (for example the sibling API's `make dev`), there is no `.puro.json`, so tools pass the environment explicitly: `puro -e gpix dart …`.

To move to a newer stable release, check the latest tag on [flutter/flutter](https://github.com/flutter/flutter/tags), then run `puro upgrade gpix <version>`. Update the version in this section and in `AGENTS.md`, adjust `environment.sdk` in `pubspec.yaml` if the Dart version changes, then run the full validation below and a native build.

Copy `config/dev.example.json` and `config/prod.example.json` to the corresponding ignored `*.local.json` files. Set `API_URL` to your private LAN HTTP origin for Dev and an HTTPS origin for Prod. Optional Dev-only `AUTH_PREFILL_IDENTIFIER` / `AUTH_PREFILL_PASSWORD` can be placed in the ignored Dev JSON; never commit them. Prod has no prefill values. Optional `PLACE_SEARCH_URL` points map place search at another Photon server (for example a self-hosted one); it defaults to the public `https://photon.komoot.io`, which is free but fair-use only.

The two launch profiles use `lib/main.dart` and the matching `dev`/`prod` flavor. Both are debug builds: Prod is a server selection, not a release signature. Changing compile-time values requires stopping and restarting F5.

Do not take an F5 session on a walk. The debugger starts every isolate paused and resumes it itself; once the phone is unplugged, nothing resumes new isolates, so any work sent to one waits forever (observed 28 September 2026: the map stopped redrawing when a large GeoJSON source was encoded in the background, and finishing a route hung on its route computation). On the Flutter/Android merged thread a paused main isolate also shows as “not responding”. For field tests run `make install-prod` (add `DEVICE=<id>` when several phones are connected): it builds Prod in release mode, installs it over the current app and starts it, with no debugger attached, so the phone can be unplugged. The release build is still signed with this computer's debug key, so it installs over the F5 build and keeps its local data.

## API over the LAN

Clone `gpixtm/api` separately. In the full workspace it is the sibling `backend/`; its `make dev` or `dart tools/dev_backend.dart` prepares Docker on the explicit private IPv4 interface from the mobile configuration. See that repository's instructions before installing or changing the API. A standalone app clone can use any compatible separately running API.

Phone and computer must share the LAN. Use a normal private address without tunnels or `adb reverse`. `localhost` on a phone means the phone, and `10.0.2.2` is emulator-specific. Check `/health` from the phone. Docker Desktop can prevent the computer reaching its own published LAN address while the phone succeeds. `make up`, `make mailpit` and `make dev-off` restore loopback; run `make dev` again for a physical phone. The Dev launch profile runs `tool/start_dev_api.dart` before F5. It starts the sibling API when available; in a standalone clone it leaves API startup to your separately configured server.

Production uses HTTPS and real accounts. Never disable certificate validation or run fixtures against production. Read the API repository's `AGENTS.md` before touching its production endpoint, configuration or deployment.

## Validate and build

Run every command through the `gpix` Puro environment:

```sh
puro flutter pub get
puro flutter gen-l10n
puro dart tool/generate_message_resolver.dart
puro dart format lib test tool
puro flutter analyze
puro flutter test
puro flutter build apk --debug --target=lib/main.dart --flavor dev --dart-define-from-file=config/dev.local.json --target-platform android-arm64 --split-per-abi
puro flutter build apk --debug --target=lib/main.dart --flavor prod --dart-define-from-file=config/prod.local.json --target-platform android-arm64 --split-per-abi
```

Integration tests requiring a live API must be configured explicitly; a skipped integration test is not a server validation. `tool/*_smoke.dart` entry points are test harnesses and must never replace the real app in a delivery. Use a full restart after native changes. Personal-device installation requires a user request.

Read [AGENTS.md](../AGENTS.md) before development and follow its commit/merge approval sequence. Keep user data, local configurations, build outputs, signing keys and credentials out of Git.
