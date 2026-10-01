import 'dart:async';

import '../domain/app_message.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

import '../domain/models.dart';
import '../domain/ports.dart';
import 'server_connection.dart';
import 'trail_codec.dart';

class GpsPositionSource implements PositionSource {
  GpsPositionSource({this.recording = false, this.languageCode});
  final bool recording;
  final String Function()? languageCode;
  AppLocalizations notificationMessages() =>
      lookupAppLocalizations(Locale(languageCode?.call() ?? 'en'));
  @override
  Future<void> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw MessageFailure(AppMessage.enableLocation);
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      throw MessageFailure(AppMessage.locationPermissionRequired);
    }
  }

  @override
  Stream<Fix> watch() => SharedPositions.instance
      .watch(
        AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 5),
          forceLocationManager: true,
          foregroundNotificationConfig: recording
              ? ForegroundNotificationConfig(
                  notificationTitle:
                      notificationMessages().recordingNotificationTitle,
                  notificationText:
                      notificationMessages().recordingNotificationBody,
                  notificationChannelName:
                      notificationMessages().recordingChannel,
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        ),
        recording: recording,
      )
      .map(
        (p) => Fix(
          GeoPoint(
            p.latitude,
            p.longitude,
            p.altitudeAccuracy <= 30 ? p.altitude : null,
          ),
          p.accuracy,
          p.timestamp,
          heading: p.heading,
        ),
      );
}

/// Geolocator keeps a single position stream per app and hands it to every
/// later caller, ignoring their settings. A map stream opened first would then
/// feed the walk recording without its foreground service: Android freezes
/// the app screen-off and the walk stops counting. Every caller shares one
/// stream here instead, reopened with the foreground service whenever a
/// recording listens, whatever the order of the calls.
class SharedPositions {
  SharedPositions(this._open);
  static final instance = SharedPositions(
    (settings) => Geolocator.getPositionStream(locationSettings: settings),
  );
  final Stream<Position> Function(LocationSettings) _open;
  final _plain = <StreamController<Position>>{};
  final _recording = <StreamController<Position>>{};
  LocationSettings? _plainSettings, _recordingSettings;
  StreamSubscription<Position>? _source;
  bool? _sourceRecording;
  Future<void> _switching = Future.value();

  Stream<Position> watch(LocationSettings settings, {required bool recording}) {
    late final StreamController<Position> controller;
    controller = StreamController<Position>(
      onListen: () {
        if (recording) {
          _recordingSettings = settings;
          _recording.add(controller);
        } else {
          _plainSettings = settings;
          _plain.add(controller);
        }
        _refresh();
      },
      onCancel: () {
        _recording.remove(controller);
        _plain.remove(controller);
        _refresh();
      },
    );
    return controller.stream;
  }

  void _refresh() {
    _switching = _switching.then((_) async {
      final wanted = _recording.isNotEmpty
          ? true
          : _plain.isNotEmpty
          ? false
          : null;
      if (wanted == _sourceRecording && _source != null) return;
      final previous = _source;
      _source = null;
      _sourceRecording = null;
      // Geolocator forgets its stream only once the last listener is gone.
      await previous?.cancel();
      if (wanted == null) return;
      _sourceRecording = wanted;
      _source = _open(wanted ? _recordingSettings! : _plainSettings!).listen(
        (position) {
          for (final c in [..._recording, ..._plain]) {
            c.add(position);
          }
        },
        onError: (Object error, StackTrace stack) {
          for (final c in [..._recording, ..._plain]) {
            c.addError(error, stack);
          }
        },
      );
    });
  }
}

class ApiElevationSource implements ElevationSource {
  ApiElevationSource(this.server);
  final ServerConnection server;
  @override
  Future<Trail> complete(Trail trail) async {
    if (trail.points.every((p) => p.elevation != null)) return trail;
    final json = TrailCodec.encode(trail);
    final segments = json['segments'] as List;
    final missing = <List<num>>[];
    for (final s in segments) {
      for (final p in s) {
        if (p[2] == null) missing.add([p[0], p[1]]);
      }
    }
    final altitudes = <dynamic>[];
    for (var i = 0; i < missing.length; i += 100) {
      final end = (i + 100).clamp(0, missing.length);
      final response = await server.request(
        '/api/elevations',
        body: {'points': missing.sublist(i, end)},
      );
      altitudes.addAll(response['elevations']);
    }
    if (altitudes.length != missing.length) {
      throw MessageFormatException(AppMessage.incompleteElevations);
    }
    var i = 0;
    for (final s in segments) {
      for (final p in s) {
        if (p[2] == null) p[2] = altitudes[i++];
      }
    }
    json['estimated'] = true;
    return TrailCodec.decode(json);
  }
}
