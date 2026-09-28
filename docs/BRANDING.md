# Gpix brand assets

The sport and adventure direction was approved on 28 September 2026: a rounded
G-shaped trail with a hollow waypoint, athletic outlined lettering, electric
lime on carbon, and clear light surfaces for maps and statistics. The
[approved concept board](branding/approved-concept.png) records the direction;
the editable vector masters are the production artwork.

## Editable sources

- [Mark](../assets/branding/source/mark.svg): the trail symbol, on a 256 × 256 canvas.
- [Wordmark](../assets/branding/source/wordmark.svg): custom outlined **Gpix**
  lettering, on a 380 × 144 canvas. No external font or font download is needed.
- [Generator](../tool/generate_brand_assets.dart): palette, compositions, export
  dimensions and Android safe areas. Every export uses the same two masters.

The masters contain paths rather than an embedded raster image. Edit them in a
vector editor, keeping the view boxes, and regenerate. Preserve the open G
counter and the waypoint hole. Keep path-only SVG geometry: outline text and
expand strokes before saving. Do not add filters, masks or external resources.

## Palette and use

| Role | Color | Use |
| --- | --- | --- |
| Carbon | `#121C18` | Launch background, dark logo, strong text |
| Lime | `#C8F35A` | Symbol on carbon, brand highlights |
| Off-white | `#F6F8F4` | Wordmark on carbon, presentation background |
| Forest | `#174B38` | Existing own/offline trail identity |
| Purple | `#6B3FA0` | Existing catalogue trail identity |

Use carbon text on lime. Lime is not a replacement for the map's semantic
colors. Own trails remain forest green, catalogue trails purple, and the GPS
position/approach blue. Application typography remains the existing Flutter
typography; outlined logo lettering is not a UI font.

## Application theme

`lib/presentation/design.dart` holds the palette tokens (`carbon`, `lime`,
`offWhite`, `forest`, `catalogueColor`, `mutedInk`) and `appTheme()`. The theme
applies the brand without changing any layout, flow or map semantics:

- Primary actions (filled buttons, switches) are carbon with off-white labels.
- Selection is lime with carbon content: drawer destination, selected chips.
- Text links and progress bars stay forest green, legible on light surfaces.
- Surfaces are off-white; map overlays, panels, dialogs and cards stay white.
- Headings and figures use heavy, tightly tracked weights. Distances,
  durations and elevations share `metricStyle`, whose tabular figures keep
  live values from shifting.
- Snack bars are carbon with a lime action. Map buttons are round and white.

Never put lime text or thin lime lines on a light surface: the contrast is
insufficient. Use a token from `design.dart` rather than a new literal color.

Use the lime symbol and light wordmark on carbon, or the carbon version on a
light surface. Keep at least one symbol stroke width of clear space around a
standalone lockup. Do not stretch, rotate, add shadows or put the light logo on
a light background. Use the symbol alone when the full name cannot be read.
The icon's square background is intentionally not rounded: Android applies its
own launcher mask.

## Generate the files

From the standalone mobile repository, with its pinned Puro environment:

```sh
puro flutter pub get
puro flutter test tool/generate_brand_assets.dart
```

The generator uses Flutter's renderer and a development-only SVG dependency.
No graphics program, Python, Node, paid service, API key or sibling repository
is needed. It overwrites only its named generated outputs. Do not edit those
outputs by hand.

The [validation record](branding/VALIDATION.md) lists the automated checks,
native builds and remaining device checks for this delivery.

To verify that the committed exports match the masters without writing files:

```sh
puro flutter test tool/generate_brand_assets.dart --dart-define=BRAND_CHECK=true
```

Use the pinned SDK for reproducible raster output; another renderer or engine
version may change antialiasing bytes.

## Deliverables

SVG and PNG exports are in [assets/branding/generated](../assets/branding/generated/):

| File prefix | Purpose |
| --- | --- |
| `gpix-mark-lime`, `gpix-mark-carbon` | Transparent standalone symbol, 512 × 512 PNG |
| `gpix-logo-on-dark`, `gpix-logo-on-light` | Transparent horizontal logo, 1200 × 400 PNG |
| `gpix-icon` | Square launcher/store artwork, 1024 × 1024 PNG |
| `gpix-splash` | Portrait presentation, 1080 × 1920 PNG |
| `gpix-splash-lockup` | Transparent centered symbol/name, 720 × 720 PNG |

The generator also writes the five Android launcher density PNGs, the native
legacy splash bitmap, and vector drawables for adaptive, monochrome and modern
splash use. The Flutter sign-in screen and drawer consume the shared light
logo. Its accessibility label uses the existing English/French `appTitle`
localization. Brand lettering is invariant in both languages.

## Android launch behavior

- Android 8–11: carbon background with the centered symbol/name lockup at
  240 dp. Explicit dimensions keep it consistent across display densities.
- Android 12+: carbon background with the native centered symbol. The OS
  controls placement and transition; the portrait presentation is not stretched
  into a full-screen native bitmap. The mark fits inside the required safe circle.
- Android 8+: adaptive launcher layers respect the safe area. Android 13+
  also has a monochrome layer for themed icons.
- Light and dark system appearances use the same approved carbon launch field.
  Flutter dismisses the launch surface on its first frame. There is no timer,
  network wait, extra startup page or artificial loading indicator.

Native requirements: [Android splash screens](https://developer.android.com/develop/ui/views/launch/splash-screen),
[adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive),
and [Flutter Android splash integration](https://docs.flutter.dev/platform-integration/android/splash-screen).

A full native rebuild/restart is required after generating Android resources;
hot reload cannot refresh the launcher or native splash. Build checks and visual
previews do not establish behavior on a physical phone. Install on a personal
phone only when requested.
