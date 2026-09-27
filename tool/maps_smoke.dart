import 'package:gpix/data/health_connect.dart';
import 'package:uuid/uuid.dart';

// Emulator-only validation target. Never used by either VS Code profile.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/data/recording_store.dart';
import 'package:gpix/data/platform_services.dart';
import 'package:gpix/application/prepare_maps.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/native_automatic_maps.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/presentation/app.dart';

class NoRegions implements MapRepository {
  @override
  Future<List<Region>> catalog() async => [];
  @override
  Future<List<LocalMap>> installed() async => [];
  @override
  Future<String?> composeStyle(List<LocalMap> maps) async => null;
  @override
  Future<void> download(Region r, void Function(double) progress) async {}
  @override
  Future<void> remove(String id) async {}
}

class Position implements PositionSource {
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() async* {
    while (true) {
      yield Fix(const GeoPoint(49.254, 4.031), 5, DateTime.now());
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}

class NoSync implements Synchronizer {
  @override
  Future<String> synchronize() async => 'Test local';
  @override
  Future<void> resolveConflicts() async {}
}

class Elevation implements ElevationSource {
  @override
  Future<Trail> complete(Trail trail) async => trail;
}

Future<void> main() async {
  if (!kDebugMode) throw StateError('Smoke target is debug only');
  WidgetsFlutterBinding.ensureInitialized();
  final root = await getApplicationSupportDirectory();
  final folder = Directory('${root.path}/maps-smoke');
  await folder.create(recursive: true);
  final db = await openLocalDatabase('${folder.path}/library.sqlite');
  final library = Library(
    SqliteTrailRepository(db),
    XmlGpxDecoder(),
    Elevation(),
  );
  final app = AppController(
    health: const AndroidHealthConnect(),
    recorder: RecordWalk(
      SqliteRecordingStore(db),
      library.repository,
      const bool.fromEnvironment('REAL_GPS')
          ? GpsPositionSource(recording: true)
          : Position(),
      const Uuid().v4,
    ),
    library: library,
    maps: NoRegions(),
    gps: const bool.fromEnvironment('REAL_GPS')
        ? GpsPositionSource()
        : Position(),
    sync: NoSync(),
    setAwake: (_) async {},
    vibrate: () async {},
    automaticMaps: PrepareMaps(NativeAutomaticMaps(folder)),
  );
  await app.initialize();
  if (app.trails.isEmpty) {
    await app.import(
      '<gpx version="1.1"><trk><name>Reims · automatic preparation</name><trkseg><trkpt lat="49.254" lon="4.031"><ele>80</ele></trkpt><trkpt lat="49.255" lon="4.034"><ele>82</ele></trkpt></trkseg></trk></gpx>',
      'Reims',
    );
  } else {
    app.select(app.trails.first);
  }
  runApp(GpixApp(app));
}
