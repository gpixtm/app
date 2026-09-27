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
  Stream<Fix> watch() =>
      Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
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
      ).map(
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
