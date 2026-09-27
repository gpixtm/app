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
