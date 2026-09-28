import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/data/native_automatic_maps.dart';
import 'package:gpix/domain/automatic_maps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native region avoids exact tile boundaries and restores durable readiness',
    () async {
      const channel = MethodChannel('plugins.flutter.io/maplibre_gl');
      final root = await Directory.systemTemp.createTemp('gpix-native-maps');
      Map<String, dynamic>? definition;
      Map<String, dynamic>? region;
      var downloads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getListOfRegions':
                return jsonEncode([?region]);
              case 'downloadOfflineRegion':
                downloads++;
                definition = Map<String, dynamic>.from(
                  call.arguments['definition'] as Map,
                );
                region = {
                  'id': 1,
                  'definition': definition,
                  'metadata': call.arguments['metadata'],
                };
                return jsonEncode(region);
              case 'getOfflineRegionStatus':
                return jsonEncode({
                  'completedResourceCount': 320,
                  'requiredResourceCount': 320,
                  'completedResourceSize': 1000000,
                  'isComplete': true,
                  'downloadProgress': 100,
                });
              default:
                return null;
            }
          });
      try {
        const area = MapArea(13, 4186, 2803, 14);
        final store = NativeAutomaticMaps(root);
        await store.restore();
        await store.remember([const StoredMapArea(area, false)]);
        await store.download(area, (_) {});
        final bounds = definition!['bounds'] as List;
        expect(bounds[0][0], greaterThan(area.bounds.south));
        expect(bounds[0][1], greaterThan(area.bounds.west));
        expect(bounds[1][0], lessThan(area.bounds.north));
        expect(bounds[1][1], lessThan(area.bounds.east));
        expect(definition!['maxZoom'], 14);
        await store.close();
        final restored = NativeAutomaticMaps(root);
        expect((await restored.restore()).single.ready, isTrue);
        await restored.download(area, (_) {});
        expect(downloads, 1);
        await restored.close();
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'launch trusts recorded readiness and still reads the legacy manifest',
    () async {
      const channel = MethodChannel('plugins.flutter.io/maplibre_gl');
      final root = await Directory.systemTemp.createTemp('gpix-native-maps');
      const ready = MapArea(13, 4186, 2803, 14),
          pending = MapArea(13, 4187, 2803, 14);
      final statuses = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getListOfRegions':
                return jsonEncode([
                  for (final (id, area) in [(1, ready), (2, pending)])
                    {
                      'id': id,
                      'definition': {
                        'bounds': [
                          [0.0, 0.0],
                          [1.0, 1.0],
                        ],
                        'mapStyleUrl':
                            'https://tiles.openfreemap.org/styles/liberty',
                        'minZoom': 0.0,
                        'maxZoom': 14.0,
                      },
                      'metadata': {'gpix-area': area.key},
                    },
                ]);
              case 'getOfflineRegionStatus':
                statuses.add(call.arguments['id'] as int);
                return jsonEncode({
                  'completedResourceCount': 1,
                  'requiredResourceCount': 1,
                  'completedResourceSize': 1,
                  'isComplete': true,
                  'downloadProgress': 100,
                });
              default:
                return null;
            }
          });
      try {
        final manifest = File('${root.path}/automatic-areas.json');
        await manifest.writeAsString(jsonEncode([ready.key, pending.key]));
        final legacy = await NativeAutomaticMaps(root).restore();
        expect(legacy.every((a) => a.ready), isTrue);
        expect(statuses, unorderedEquals([1, 2]));
        statuses.clear();
        final store = NativeAutomaticMaps(root);
        await store.remember([
          const StoredMapArea(ready, true),
          const StoredMapArea(pending, false),
        ]);
        final restored = await store.restore();
        expect(restored.map((a) => a.area.key), [ready.key, pending.key]);
        expect(restored.every((a) => a.ready), isTrue);
        expect(statuses, [2]);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await root.delete(recursive: true);
      }
    },
  );
}
