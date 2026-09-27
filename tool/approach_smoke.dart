// Emulator-only UI check using a captured real Valhalla response. Never delivered.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/prepare_maps.dart';
import 'package:gpix/data/approach_source.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/native_automatic_maps.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/approach.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/presentation/app.dart';

import 'maps_smoke.dart' show NoRegions, NoSync, Elevation;

class CapturedRoute implements ApproachSource {
  @override
  Future<ApproachRoute> calculate(
    GeoPoint origin,
    Trail target,
    GeoPoint destination,
  ) async => decodeApproach(
    jsonDecode(
      utf8.decode(
        base64Decode(const String.fromEnvironment('APPROACH_RESPONSE')),
      ),
    ),
    target,
  );
}

class ReimsPosition implements PositionSource {
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => Stream.periodic(
    const Duration(seconds: 1),
    (_) => Fix(const GeoPoint(49.254, 4.03), 5, DateTime.now()),
  );
}

Future<void> main() async {
  if (!kDebugMode) throw StateError('Debug only');
  WidgetsFlutterBinding.ensureInitialized();
  final root = await getApplicationSupportDirectory();
  final db = await openLocalDatabase('${root.path}/approach-smoke.sqlite');
  final library = Library(
    SqliteTrailRepository(db),
    XmlGpxDecoder(),
    Elevation(),
  );
  final target = Trail(
    id: '319bc21b-1710-490b-9a03-36953046a0ab',
    name: 'Reims · trail start',
    segments: [
      [const GeoPoint(49.256, 4.034), const GeoPoint(49.26, 4.04)],
    ],
    pois: [],
  );
  await library.repository.save(target);
  final app = AppController(
    library: library,
    maps: NoRegions(),
    gps: ReimsPosition(),
    sync: NoSync(),
    setAwake: (_) async {},
    vibrate: () async {},
    approachSource: CapturedRoute(),
    automaticMaps: PrepareMaps(
      NativeAutomaticMaps(Directory('${root.path}/maps-smoke')),
    ),
  );
  await app.initialize();
  app.mapFix = Fix(const GeoPoint(49.254, 4.03), 5, DateTime.now());
  await app.joinTrail(target);
  runApp(GpixApp(app));
}
