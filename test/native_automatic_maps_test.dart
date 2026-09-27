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
        await store.remember([area]);
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
}
