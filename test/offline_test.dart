import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/data/offline_maps.dart';

void main() {
  test('real PMTiles fixture verifies with zero remote resources; corruption rejected', () async {
    final dir = await Directory.systemTemp.createTemp('gpix-map');
    for (final name in ['map.pmtiles', 'style.json', 'bundle.json']) {
      await File('assets/demo/$name').copy('${dir.path}/$name');
    }
    await validateBundle(dir);
    final style = jsonDecode(
      await File('${dir.path}/resolved-style.json').readAsString(),
    );
    expect(
      style['sources']['basemap']['url'],
      startsWith('pmtiles://file:///'),
    );
    await File('${dir.path}/map.pmtiles').writeAsBytes([0, 1, 2]);
    await expectLater(validateBundle(dir), throwsFormatException);
    await dir.delete(recursive: true);
  });
  test(
    'external glyph dependency rejected even with matching manifest hash',
    () async {
      final dir = await Directory.systemTemp.createTemp('gpix-map');
      for (final name in ['map.pmtiles', 'style.json', 'bundle.json']) {
        await File('assets/demo/$name').copy('${dir.path}/$name');
      }
      final styleFile = File('${dir.path}/style.json');
      final style = jsonDecode(await styleFile.readAsString());
      style['glyphs'] = 'https://example.invalid/{fontstack}/{range}.pbf';
      await styleFile.writeAsString(jsonEncode(style));
      final manifestFile = File('${dir.path}/bundle.json');
      final manifest = jsonDecode(await manifestFile.readAsString());
      manifest['files']['style.json'] =
          (await sha256.bind(styleFile.openRead()).first).toString();
      await manifestFile.writeAsString(jsonEncode(manifest));
      await expectLater(validateBundle(dir), throwsFormatException);
      await dir.delete(recursive: true);
    },
  );
  test(
    'domain and application have no Flutter, data or presentation imports',
    () {
      for (final folder in ['lib/domain', 'lib/application']) {
        for (final file
            in Directory(folder)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))) {
          final code = file.readAsStringSync();
          expect(
            RegExp("import ['\"](?:package:|.*(?:data|presentation)/)")
                .hasMatch(code),
            false,
            reason: file.path,
          );
        }
      }
    },
  );
}
