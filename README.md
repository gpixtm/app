<p align="center">
  <img src="assets/branding/generated/gpix-logo-on-light.png" alt="Gpix" width="300">
</p>

# Gpix

**Gpix** is an offline-first hiking and walking app for Android. Import or discover a trail, get its map offline automatically, follow it with voice guidance even with the screen off, and record your walks. Your library follows you to your next phone, and the trails and places you add are shared with every walker.

English and French are fully supported. The server side lives in [gpixtm/api](https://github.com/gpixtm/api).

## Features

- **One central map.** Every trail with a visible portion (yours, other walkers' and open-data trails from OpenStreetMap) is marked by a pin. Select one to draw it, browse without interrupting the walk in progress.
- **Automatic offline maps.** Visible areas are downloaded while online (OpenFreeMap vector tiles), and a trail's whole corridor is prepared as soon as it is imported. Offline, only really downloaded areas are shown, and partial preparation is reported honestly.
- **Walking navigation.** Join the nearest point of the trail (not its start) through a computed walking approach, or hand over to Google Maps. Direction changes are announced about 100 m ahead by offline text-to-speech and notifications, screen off included, with a kilometre-by-kilometre summary (distance, pace compared with your usual speed, steps, estimated active calories).
- **Recording.** Record real walks with or without a GPX, in the background through an Android foreground service. Pause, stop following and finish are separate actions.
- **Planning and history.** Split a long trail into days, find each walk again in its route's history, and compare walks on the same route over time.
- **Collaborative trails.** Trails added by anyone are shared once, deduplicated by their line. Walkers who covered at least 90 % of a trail can review it, and anyone can add named places near a trail or attach a GPX file of waypoints. Walks, speeds and health data stay private.
- **Health Connect.** Optionally read heart rate, steps and active calories for a walk (from a Zepp/Amazfit or any compatible watch), and write finished walks as exercise sessions.
- **Offline first, not local only.** Everything works without a network after the first sign-in, and syncs when the connection comes back, with explicit conflict handling.

## Install

Download the latest APK from [Releases](https://github.com/gpixtm/app/releases/latest), check its SHA-256 against the `.sha256` file published next to it, and install it on an Android 8.0+ phone (allow installation from your browser or file manager when asked). New releases install over the previous one and keep your data.

The published APK connects to the project's public server; create an account from the app. To use your own server, build the app with your server's address (below).

## Build from source

Requirements: [Puro](https://puro.dev) (Flutter version manager), the Android SDK with Java 21 (Android Studio's bundled JDK works), and an Android device or emulator. Flutter is pinned to **3.47.5** stable.

```sh
git clone https://github.com/gpixtm/app.git gpix-app
cd gpix-app
puro create gpix 3.47.5
puro use gpix
puro flutter pub get
```

Point the app at a server by copying `config/prod.example.json` to `config/prod.local.json` (HTTPS) or `config/dev.example.json` to `config/dev.local.json` (HTTP on a private LAN address), then set `API_URL`. These `*.local.json` files are ignored by Git. To run your own server, follow the [API README](https://github.com/gpixtm/api#quick-start).

```sh
puro flutter run --flavor dev --dart-define-from-file=config/dev.local.json    # debug, local server
make build-prod                                                                 # release APK for config/prod.local.json
```

VS Code launch profiles are included. [docs/DEBUG-VSCODE.md](docs/DEBUG-VSCODE.md) covers the SDK setup, reaching a local API from a physical phone, release signing and field-testing builds.

## Architecture

Clean Architecture in Dart, with thin Kotlin adapters for Android-specific capabilities:

```
lib/domain/        entities, ports and pure rules (trail geometry, identity, coverage)
lib/application/   orchestration through ports (AppController, navigation, sync)
lib/data/          SQLite, GPX/XML, HTTP, files, secure storage, location, native bridges
lib/presentation/  widgets, theme, map rendering (MapLibre), localization glue
lib/l10n/          English (template) and French ARB catalogues
android/           flavors (dev, prod), foreground service, turn guidance, Health Connect
test/              unit, widget and (opt-in) integration tests
tool/              code generators and manual smoke harnesses
```

The local SQLite database and an outbox of immutable operations make every change durable before it is sent. Sessions, libraries and maps are isolated per server and account.

## Documentation

| Topic | Document |
| --- | --- |
| Product behaviour and accepted decisions | [docs/PRODUCT.md](docs/PRODUCT.md) |
| Development setup, LAN API, signed builds | [docs/DEBUG-VSCODE.md](docs/DEBUG-VSCODE.md) |
| Adding or changing user-visible text | [docs/LOCALIZATION.md](docs/LOCALIZATION.md) |
| Logo, icon, splash and theme | [docs/BRANDING.md](docs/BRANDING.md) |

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, checks and project rules, and [SECURITY.md](SECURITY.md) to report a vulnerability privately.

## Licence and credits

Gpix is free software under the [GNU General Public License v3.0](LICENSE).

- Maps: [OpenFreeMap](https://openfreemap.org/), [MapLibre](https://maplibre.org/), data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors (ODbL).
- Place search: [Photon](https://photon.komoot.io/) by komoot (fair use; configurable with `PLACE_SEARCH_URL`).
- The bundled demo map comes from the [Protomaps PMTiles](https://github.com/protomaps/PMTiles) samples (see [assets/demo/NOTICE.md](assets/demo/NOTICE.md)).
