# Brand asset validation — 28 September 2026

Validated on `develop` with Puro's `gpix` environment: Flutter 3.47.5,
Dart 3.13.4. This delivery includes the editable masters, deterministic exports,
native launcher/splash resources, shared sign-in/drawer logo and the branded
application theme (palette, button, selection and figure styles).

## Passed

- Generator: 24 outputs created, then matched by
  `puro flutter test tool/generate_brand_assets.dart --dart-define=BRAND_CHECK=true`.
- Native safe areas: rendered nontransparent pixels stay inside both the
  adaptive-launcher and Android 12 splash safe circles.
- Visual inspection: symbol, transparent wordmark, icon and portrait splash;
  the waypoint hole and G counter remain open.
- `puro flutter analyze --no-pub`: no issues.
- `puro flutter test --no-pub`: 211 tests passed, 2 skipped (HTTP integration
  without a server).
- Theme preview: a temporary widget render with Roboto of buttons, metrics,
  chips, switch, drawer selection, progress bar and logo was inspected, then
  removed. It is not a device check.
- Dev and Prod arm64 debug APK builds passed with `lib/main.dart`.
  Both APKs contain the new native vector resources and legacy launch resource.
  Only the logo PNG used by Flutter is bundled as a Flutter brand asset.
- Diff review, `git diff --check`, and local documentation links passed.

The first Dev build hit stale incremental Android resource output after the old
`drawable-v21/launch_background.xml` override was removed. Re-running
`mergeDevDebugResources` and `mergeProdDebugResources` with `--rerun-tasks`
rebuilt those resources; both full Flutter builds then passed. No source
workaround, Gradle upgrade or build-directory deletion was needed.

## Build records

Commands (no server configuration or network requests were needed):

```sh
puro flutter build apk --no-pub --debug --target=lib/main.dart --flavor dev --target-platform android-arm64 --split-per-abi
puro flutter build apk --no-pub --debug --target=lib/main.dart --flavor prod --target-platform android-arm64 --split-per-abi
```

| APK under `build/app/outputs/flutter-apk/` | SHA-256 |
| --- | --- |
| `app-arm64-v8a-dev-debug.apk` | `158a68109c6cdc5e112aa21d9bc1b3a8d7399593e11a468b3b566a61a123e524` |
| `app-arm64-v8a-prod-debug.apk` | `55c4d229ed580f887a08272740ff66bfe55e228443ba5b38199738a7fc17399c` |

These are local validation builds, not store-signed releases. Build products
remain ignored. Physical-device and emulator cold-start, launcher-mask and
themed-icon checks were not performed; no APK was installed on a personal phone.
