import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

export '../domain/text_folding.dart' show foldForSearch;

/// Brand palette, see docs/BRANDING.md.
const carbon = Color(0xff121c18);
const lime = Color(0xffc8f35a);
const offWhite = Color(0xfff6f8f4);

/// The walker's own trails (imported, created or made available offline).
const forest = Color(0xff174b38);

/// Trails of the catalogue that are not on the phone. The walker's own trails
/// keep [forest].
const catalogueColor = Color(0xff6b3fa0);
const catalogueHex = '#6b3fa0';
const ownTrailHex = '#184f36';
const paper = offWhite;
const ink = carbon;

/// Secondary text: captions, metric labels and explanations.
const mutedInk = Color(0xff5f6b66);

/// Large figures (distances, durations, elevations) in the brand's tight,
/// heavy numerals. Tabular figures keep live values from jittering.
const metricStyle = TextStyle(
  fontWeight: FontWeight.w800,
  letterSpacing: -.6,
  height: 1.15,
  color: ink,
  fontFeatures: [FontFeature.tabularFigures()],
);
String decimal(num value, [int digits = 1]) =>
    NumberFormat(digits == 0 ? '0' : '0.${'0' * digits}').format(value);
String kilometers(double metres) =>
    '${NumberFormat('0.0').format(metres / 1000)} km';

/// A trail length short enough for a map label: "4.5 km", "12 km".
String shortKilometers(double metres) => metres >= 10000
    ? '${NumberFormat('0').format(metres / 1000)} km'
    : kilometers(metres);
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: forest).copyWith(
    primary: carbon,
    onPrimary: offWhite,
    primaryContainer: lime,
    onPrimaryContainer: carbon,
    secondary: forest,
    onSecondary: Colors.white,
    secondaryContainer: lime,
    onSecondaryContainer: carbon,
    tertiary: forest,
    onTertiary: Colors.white,
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: mutedInk,
    inverseSurface: carbon,
    onInverseSurface: offWhite,
    inversePrimary: lime,
    surfaceTint: Colors.transparent,
  );
  const heading = TextStyle(fontWeight: FontWeight.w800, color: ink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    textTheme: TextTheme(
      headlineLarge: heading.copyWith(fontSize: 34, letterSpacing: -1.4),
      headlineMedium: heading.copyWith(fontSize: 28, letterSpacing: -1),
      headlineSmall: heading.copyWith(fontSize: 24, letterSpacing: -.7),
      titleLarge: heading.copyWith(fontSize: 22, letterSpacing: -.4),
      // Button labels.
      labelLarge: const TextStyle(fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: Color(0xffc9d0cb)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: forest),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: CircleBorder(),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: forest,
      linearTrackColor: Color(0xffdfe5dc),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: lime,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: carbon,
      contentTextStyle: TextStyle(color: offWhite),
      actionTextColor: lime,
    ),
    chipTheme: const ChipThemeData(
      selectedColor: lime,
      checkmarkColor: carbon,
      side: BorderSide(color: Color(0xffc9d0cb)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {this.good = false, super.key});
  final String label;
  final bool good;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: good ? const Color(0xffe0eddd) : const Color(0xffffedcd),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: good ? forest : const Color(0xff6b4b14),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
