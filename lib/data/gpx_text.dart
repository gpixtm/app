import '../domain/app_message.dart';

import 'dart:convert';

bool damagedText(String value) =>
    RegExp('\uFFFD|\u00c3[\u0080-\u00bf]|\u00c2[\u0080-\u00bf]|\u00e2\u20ac')
        .hasMatch(value);

String checkedGpxText(String value) {
  if (damagedText(value)) {
    throw MessageFormatException(AppMessage.damagedGpx);
  }
  return value;
}

/// Decode the file bytes exactly once, respecting XML's encoding declaration.
String decodeGpxBytes(List<int> bytes) {
  if (bytes.length > 50 * 1024 * 1024) {
    throw MessageFormatException(AppMessage.gpxSizeLimit);
  }
  if (bytes.length >= 2 &&
      ((bytes[0] == 255 && bytes[1] == 254) ||
          (bytes[0] == 254 && bytes[1] == 255))) {
    final little = bytes[0] == 255;
    if (bytes.length.isOdd) {
      throw MessageFormatException(AppMessage.incompleteUtf16);
    }
    final units = <int>[];
    for (var i = 2; i < bytes.length; i += 2) {
      units.add(
        little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
      );
    }
    for (var i = 0; i < units.length; i++) {
      if (units[i] >= 0xd800 && units[i] <= 0xdbff) {
        if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
          throw MessageFormatException(AppMessage.invalidUtf16);
        }
      } else if (units[i] >= 0xdc00 && units[i] <= 0xdfff) {
        throw MessageFormatException(AppMessage.invalidUtf16);
      }
    }
    return String.fromCharCodes(units);
  }
  final prefix = String.fromCharCodes(bytes.take(256));
  final encoding = RegExp(
    'encoding\\s*=\\s*["\x27]([^"\x27]+)',
    caseSensitive: false,
  ).firstMatch(prefix)?.group(1)?.toLowerCase();
  if (encoding == 'iso-8859-1') return latin1.decode(bytes);
  if (encoding == 'windows-1252') {
    const special = [
      0x20ac,
      0x81,
      0x201a,
      0x192,
      0x201e,
      0x2026,
      0x2020,
      0x2021,
      0x2c6,
      0x2030,
      0x160,
      0x2039,
      0x152,
      0x8d,
      0x17d,
      0x8f,
      0x90,
      0x2018,
      0x2019,
      0x201c,
      0x201d,
      0x2022,
      0x2013,
      0x2014,
      0x2dc,
      0x2122,
      0x161,
      0x203a,
      0x153,
      0x9d,
      0x17e,
      0x178,
    ];
    return String.fromCharCodes(
      bytes.map((b) => b >= 128 && b < 160 ? special[b - 128] : b),
    );
  }
  if (encoding != null &&
      encoding != 'utf-8' &&
      encoding != 'utf8' &&
      encoding != 'us-ascii') {
    throw MessageFormatException(AppMessage.unsupportedGpxEncoding(encoding));
  }
  return utf8.decode(
    bytes,
  ); // Strict: never replace invalid bytes with question marks.
}
