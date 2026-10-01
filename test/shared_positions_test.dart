import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpix/data/platform_services.dart';

/// Behaves like the Geolocator Android plugin: one stream per app, returned
/// to every later caller whatever settings it asks for, until nobody listens.
class CachingGeolocator {
  final opened = <LocationSettings>[];
  StreamController<Position>? _open;
  Stream<Position> call(LocationSettings settings) {
    if (_open case final open?) return open.stream;
    opened.add(settings);
    final controller = StreamController<Position>.broadcast();
    controller.onCancel = () {
      if (identical(_open, controller)) _open = null;
    };
    _open = controller;
    return controller.stream;
  }

  bool get foreground =>
      _open != null &&
      (opened.last as AndroidSettings).foregroundNotificationConfig != null;
  void emit(Position position) => _open?.add(position);
}

Position at(double latitude) => Position(
  latitude: latitude,
  longitude: 6,
  timestamp: DateTime(2026, 10, 1, 9),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

AndroidSettings settings({required bool recording}) => AndroidSettings(
  foregroundNotificationConfig: recording
      ? const ForegroundNotificationConfig(
          notificationTitle: 'Recording',
          notificationText: 'Walk',
        )
      : null,
);

void main() {
  test('a map stream opened first never keeps the recording without its '
      'foreground service', () async {
    final geolocator = CachingGeolocator();
    final positions = SharedPositions(geolocator.call);
    final map = <Position>[], walk = <Position>[];
    final browsing = positions
        .watch(settings(recording: false), recording: false)
        .listen(map.add);
    await pumpEventQueue();
    expect(geolocator.foreground, isFalse);

    final recording = positions
        .watch(settings(recording: true), recording: true)
        .listen(walk.add);
    await pumpEventQueue();
    expect(geolocator.foreground, isTrue, reason: 'reopened for the walk');

    geolocator.emit(at(45));
    await pumpEventQueue();
    expect(walk, hasLength(1));
    expect(map, hasLength(1), reason: 'the map keeps its positions');

    // The map closing changes nothing for the walk.
    await browsing.cancel();
    await pumpEventQueue();
    expect(geolocator.foreground, isTrue);

    // The walk finished, the map browsing again: no foreground service.
    await recording.cancel();
    final again = positions
        .watch(settings(recording: false), recording: false)
        .listen(map.add);
    await pumpEventQueue();
    expect(geolocator.foreground, isFalse);
    await again.cancel();
    await pumpEventQueue();
    expect(geolocator.opened, hasLength(3));
  });
}
