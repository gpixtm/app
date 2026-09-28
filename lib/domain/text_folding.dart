/// Case- and accent-insensitive form for filtering and comparing user names.
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
