import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const forest = Color(0xff174b38);
const paper = Color(0xfff7f8f2);
const ink = Color(0xff172a22);
String decimal(num value, [int digits = 1]) =>
    NumberFormat(digits == 0 ? '0' : '0.${'0' * digits}').format(value);
String kilometers(double metres) =>
    '${NumberFormat('0.0').format(metres / 1000)} km';
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: forest,
    primary: forest,
    surface: paper,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
      color: ink,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    filled: true,
  ),
);

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

/// Case- and accent-insensitive form for filtering user names.
String foldForSearch(String text) {
  // Latin-1 accented letters, then the oe/ae ligatures.
  const from =
      '\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e7\u00e8\u00e9\u00ea\u00eb'
      '\u00ec\u00ed\u00ee\u00ef\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f9'
      '\u00fa\u00fb\u00fc\u00fd\u00ff';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(
      index >= 0
          ? to[index]
          : char == '\u0153'
          ? 'oe'
          : char == '\u00e6'
          ? 'ae'
          : char,
    );
  }
  return buffer.toString();
}
