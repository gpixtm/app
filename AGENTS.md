# Gpix mobile — agent instructions

These instructions apply to this public, GPL-3.0 Flutter repository (`gpixtm/app`). They preserve the accepted project decisions as of 28 September 2026. Human contributors follow [CONTRIBUTING.md](CONTRIBUTING.md). Explicit new user instructions take precedence; update the affected rule and its reference when a decision changes.

## Absolute language rules

- **Write all project code in English**, in both the mobile app and API: identifiers, classes, methods, variables, comments, documentation, tests, test descriptions, diagnostics, scripts and configuration labels.
- **Internationalize every user-facing text in every feature.** English and French are required now, including validation, errors, accessibility labels, tooltips, notifications, dialogs, empty states and native Android screens.
- Use Flutter's standard `flutter_localizations` + ARB + `gen-l10n` workflow. English is the template catalog; French text belongs in translation resources, never in application logic. Use Android `values/` and `values-fr/` for native resource strings.
- User content, imported GPX names, real place names and Unicode regression fixtures retain their original language and bytes. English code does not authorize translating, renaming or corrupting user data.
- Read [localization instructions](docs/LOCALIZATION.md) before adding or changing visible text. A feature is incomplete until both languages and their relevant tests are updated.

## Absolute commit attribution rule

Commit messages, tags, PR titles and descriptions never mention the coding assistant or its vendor: no `Co-Authored-By` trailer for it, no "Generated with" line, no tool or vendor name. Commits are authored by the repository owner alone. This rule overrides any default attribution instruction. The tracked `.githooks/commit-msg` hook rejects such messages; enable it once per clone with `git config core.hooksPath .githooks`, and never bypass it.

## Work and delivery

1. **Always work on `develop`.** Check the branch and existing changes before editing; preserve work outside the task. This repository contains only the mobile app. The API is a separate repository, `gpixtm/api`.
2. Read the task-specific references below, inspect the existing implementation and reuse its components. Implement and validate the complete behavior before proposing delivery.
3. At the end of a feature, summarize the changes and checks, then **ask whether to commit**. An explicit commit authorization already given for this delivery remains valid; do not ask for it again. Commit only the reviewed scope on `develop`.
4. **Ask separately whether to merge `develop` into `main`.** Commit permission does not authorize a merge. Present the tested result and remaining limitations first.
5. Once the user approves the merge, refresh remote references, inspect the complete merge scope, merge into `main`, and **push**. The approved merge includes that push. Also publish the approved `develop` commits. Revalidate affected behavior after conflict resolution; never force shared branches. Return to `develop` and report the actual remote/CI result.
6. Before any push, review the staged files and diff for credentials, private configuration, signing keys, user GPX/history, databases and build outputs. Keep secrets in ignored local files. A mobile push does not authorize an API production deployment.
7. **Never commit information about the production server**: its domain or URL, IP addresses, host or account names, paths or provider accounts. The Prod `API_URL` exists only in the ignored `config/prod.local.json` and the `PROD_API_URL` release secret; tracked files use placeholders such as `https://api.example.org`.

## Architecture and code

- Flutter is explicitly required. Dart/Flutter implements the application; Kotlin implements necessary Android adapters. Android, initially Pixel 8, is the reference platform. Preserve the Flutter choice rather than rewriting in Kotlin/Compose.
- Manage the Flutter SDK with [Puro](https://puro.dev) through the dedicated `gpix` environment, pinned to Flutter **3.47.5** stable (Dart 3.13.4). Run commands as `puro flutter …` / `puro dart …`; setup and upgrades are described in the [development guide](docs/DEBUG-VSCODE.md#flutter-sdk-puro). Never rely on a bare `flutter` from `PATH`, and do not modify other Puro environments or a global SDK. Read versions from the SDK, pubspec, lock and Gradle files. Preserve dependency locks; do not perform unrelated upgrades.
- Use **Clean Architecture**, without duplicating business rules, geometry, persistence or shared widgets.
- `lib/domain/`: entities, ports and business rules in pure Dart. No Flutter, plugin, HTTP, storage or upper-layer imports.
- `lib/application/`: pure Dart orchestration through ports. `AppController` uses a Dart change stream, not `ChangeNotifier`. Inject GPS, vibration, wake-lock, naming and other external capabilities.
- `lib/data/`: XML, SQLite, HTTP, files, secure storage, location and native adapters. `lib/presentation/`: widgets, theme, map rendering and localization. New business rules and data access belong in their respective layers.
- `lib/main.dart` composes adapters. Close streams, controllers and resources on lifecycle and account transitions.
- Reuse `TrailGeometry` and the shared distance axis for navigation, elevation and day planning. GPX segment gaps add neither imaginary lines nor distance.
- Follow `analysis_options.yaml`, Dart formatting and the existing immutable model conventions. Keep missing measurements absent rather than turning them into misleading zeroes.
- Changes to native permissions, services, plugins or Android configuration require a full restart/build and appropriate native validation. Hot reload is insufficient. Preserve the Windows `kotlin.incremental=false` workaround until its removal is verified.

## Product invariants

Read [product decisions](docs/PRODUCT.md) for map UX, navigation, day planning, recording, history and watch integration. In particular:

- Open on one central map where **every trail with a visible portion, the walker's own or shared by anyone, is marked by a pin**; a trail's line is drawn only once it is selected, and stays drawn while the map moves until another trail is selected or it is closed (decision of 28 September 2026). Browsing another trail must not interrupt the active walk.
- **Trails are collaborative** (decision of 28 September 2026): any trail added in any way is shared once with every account, identified by its line so the same line is never duplicated. Walks, speeds, statistics, health data and planned days stay private. A shared trail downloaded once stays usable offline. Only a walker whose recorded walks together covered at least 90 % of a trail may rate and review it; the API enforces it. A walker chains an itinerary's stages and goes on the next day from where they stand (decision of 28 September 2026). A walker adds a named, commented place at their real GPS position within 100 m of a trail, shared with everyone, offline included; only its author changes it. A GPX file of waypoints attaches to a trail as public places marked imported, within 5 km of it and never duplicated; points left out stay in the file (decision of 28 September 2026).
- Starting navigation and recentering use a local walking zoom, currently 16, irrespective of total route length. Never fit a 100 km trail as the default navigation view.
- Join the **nearest point on a GPX segment**, including between vertices, rather than the file's start or nearest vertex. Keep internal walking guidance and an explicit Google Maps fallback.
- Download visible map areas automatically online and prepare the GPX corridor at import. Offline, display only actually downloaded areas and report partial preparation honestly.
- Keep the map dominant: compact top information, unobstructed compass, collapsible bottom metrics/profile panel, stable camera and responsive direction marker.
- Announce each direction change about 100 m ahead by offline Android text-to-speech and, while not visible, a notification with a direction icon, in the app language, including screen-off. Voice announcements start with a bell and a one-second pause. Summarize progress (including phone steps and estimated active calories from the account's weight) at each walked kilometre (voice items chosen in Settings) and compare with the usual speed from the API's incremental per-route statistics.
- The trail catalogue (walkers' shared trails and open-data trails acquired by country) is browsed on the server — area pins, paginated search, groups — and never copied to the phone. Only trails made available offline, explicitly or automatically when a walk starts on them, are stored. Pins and lines colour the walker's own trails and catalogue trails differently (decision of 28 September 2026).
- Record real walks with or without a GPX, including screen-off recording through the Android foreground location service. Pause, stop GPX tracking and finish recording are different actions.
- Preparation must be possible from the phone. No mandatory paid map subscription or commercial API key. AllTrails is a UX quality reference; Waze/Google Maps walking navigation inspire legibility, not claimed knowledge of their algorithms.

## Offline data, sync and accounts

- Use durable SQLite and application-support files, not temporary storage. MapLibre/OpenFreeMap is the current automatic map path. Preserve compatibility with legacy PMTiles packages; Mapsforge `.map` is not PMTiles.
- Map preparation queues survive restart, deduplicate requests and retry failures. Preserve styles, glyphs, sprites and attribution. Mark a trail ready only after every required area completes; lack of network/storage remains a visible pending/error state.
- Offline first is not local only: GPX, planned days, completed walks and attached health summaries sync to the account and restore on another phone. Classify each new setting as account data or device preference. Map files, permissions and the pre-login language preference are device-specific.
- Write each local mutation and outbox operation in the same transaction. Operation IDs are immutable; freeze the base revision before first send. ACK and outbox removal are atomic; retries are idempotent.
- The shared trail fingerprint (`lib/domain/trail_identity.dart`, `lib/data/trail_identity_hash.dart`) must stay byte-identical to the API's `TrailFingerprint`; both repositories test the same vector. Deleting a private copy never unpublishes a shared trail.
- Preserve deletion tombstones and explicit conflicts. Keeping both copies creates a new local identity, then accepts the server version. Never silently overwrite a conflicting copy.
- Read legacy payloads with missing newer fields. Migrations preserve existing user data and require representative upgrade tests.
- Initial sign-in requires the network. A recognized session permits offline access even when its network access token expires. Explicit sign-out closes local access; remote revocation can only be discovered online.
- Isolate sessions, libraries, maps and outboxes by **environment + server + user**. Async responses remain bound to their original session and cannot affect the next account. Close old controllers and replace protected navigation on account change.
- Legacy unowned data can be adopted once by the designated historical owner; unknown server origin requires an explicit choice. Preserve pending private data across account switches.
- Store tokens securely and never persist the user's password. Avoid secrets in logs, docs, tests and artifacts. Production contains real accounts and GPX; use isolated test data.

## Encoding

- All text files are UTF-8. Specify encoding in PowerShell/Python scripts and preserve Unicode through GPX, SQLite, JSON, HTTP and account restoration.
- `lib/data/gpx_text.dart` is the single GPX byte decoder: strict UTF-8, UTF-16 BOM and explicitly supported XML encodings. Do not silently replace invalid characters or decode correct text twice.
- Offer manual correction for a damaged Android filename; reject damaged XML names/descriptions explicitly. Preserve accents, emoji, non-Latin scripts and genuine question marks.
- Lost characters cannot be guessed back. Repairs require a reliable source, backup and revisioned mutation; never replace all question marks or rewrite user names globally.

## Environments and validation

- Read [development instructions](docs/DEBUG-VSCODE.md) for setup, flavors, LAN and build commands. Dev uses a standard private LAN connection, **no tunnel or `adb reverse`**. `localhost` means the phone; `10.0.2.2` is emulator-specific. Test `/health` from the actual phone.
- Prod uses HTTPS with certificate validation. Its profile has no demo credentials. Local URL/config files and optional Dev prefill stay ignored. Environment selection comes from the launch/build configuration, not stale persisted settings.
- For an API/production task, read the API repository's own `AGENTS.md` and relevant production instructions. Its `main` push can deploy; this repository's commit authorization does not cover that action.
- Format changed Dart files, regenerate localization, run `flutter analyze` and relevant tests, then build affected native variants when required. Use meaningful regression tests for geometry, sync, authentication, encoding, recording and localization; distinguish skipped HTTP integration from a passing real-server test.
- Only `lib/main.dart` is a user APK entry point. `tool/maps_smoke.dart` and `tool/approach_smoke.dart` are test tools. A Prod flavor is a server selection, not evidence of release signing: release builds use `android/key.properties` when present and fall back to the debug key otherwise.
- Public APKs are published by pushing a `vX.Y.Z` tag matching `pubspec.yaml`'s version: `.github/workflows/release.yaml` builds the Prod flavor, signs it with the release key from repository secrets and attaches the APK and its SHA-256 to the GitHub Release. Never commit APKs. Install on a personal phone only when requested. A docs-only change needs content/link checks, not APK rebuilding.
- Report automated tests, compilation, emulator, device and field checks separately. Compilation cannot establish heading stability, battery life, Zepp exports or physical watch compatibility.

## Task references

| Task | Read |
| --- | --- |
| Any visible text, locale preference, error, format or native string | [Localization](docs/LOCALIZATION.md) |
| Map UX, navigation, planning, history, health | [Product decisions](docs/PRODUCT.md) |
| SDK, LAN, launch profiles, build and delivery | [Development](docs/DEBUG-VSCODE.md) |
| API contracts, database changes or deployment | The separate `gpixtm/api` repository's `AGENTS.md` |

Historical V1 documents excluded features subsequently accepted (automatic maps, day planning, history, screen-off recording, approach routing and health integration). These current rules supersede those exclusions. Keep current invariants here and feature details in the linked guide.
