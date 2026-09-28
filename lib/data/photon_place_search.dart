import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/app_message.dart';
import '../domain/models.dart';
import '../domain/place_search.dart';

/// OpenStreetMap geocoding through a Photon server (no key, fair use).
/// A self-hosted Photon exposes the same API: only [base] changes.
class PhotonPlaceSearch implements PlaceSearch {
  PhotonPlaceSearch(
    this.client, {
    String base = 'https://photon.komoot.io',
    this.languageCode,
  }) : base = Uri.parse(base.isEmpty ? 'https://photon.komoot.io' : base);
  final http.Client client;
  final Uri base;
  final String Function()? languageCode;

  /// Photon only translates these languages; others use local names.
  static const _languages = {'en', 'fr', 'de'};

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async {
    final text = query.trim();
    if (text.length < 2) return const [];
    final language = languageCode?.call();
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/',
      queryParameters: {
        'q': text,
        'limit': '8',
        if (_languages.contains(language)) 'lang': language,
        if (near != null) ...{
          'lat': near.lat.toStringAsFixed(4),
          'lon': near.lon.toStringAsFixed(4),
        },
      },
    );
    final http.Response response;
    try {
      response = await client
          .get(uri, headers: {'User-Agent': 'Gpix/1.0 (Android hiking app)'})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw MessageFailure(AppMessage.placeSearchUnavailable);
    }
    if (response.statusCode != 200) {
      throw MessageFailure(AppMessage.placeSearchUnavailable);
    }
    try {
      return decodePhoton(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw MessageFailure(AppMessage.placeSearchUnavailable);
    }
  }
}

List<Place> decodePhoton(String body) {
  final json = jsonDecode(body);
  if (json is! Map || json['features'] is! List) {
    throw const FormatException('Photon response without features');
  }
  final places = <Place>[];
  for (final feature in json['features'] as List) {
    if (feature is! Map) continue;
    final coordinates = (feature['geometry'] as Map?)?['coordinates'];
    final properties = feature['properties'] as Map? ?? const {};
    if (coordinates is! List || coordinates.length < 2) continue;
    final point = GeoPoint(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
    if (!point.valid) continue;
    String? text(String key) {
      final value = properties[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final street = [
      text('housenumber'),
      text('street'),
    ].whereType<String>().join(' ');
    final name = text('name') ?? (street.isEmpty ? null : street);
    if (name == null) continue;
    final detail = <String>[];
    for (final part in [
      if (text('name') != null && street.isNotEmpty) street,
      text('postcode'),
      text('city'),
      text('county'),
      text('state'),
      text('country'),
    ].whereType<String>()) {
      if (part != name && !detail.contains(part)) detail.add(part);
    }
    final extent = properties['extent'];
    places.add(
      Place(
        name: name,
        detail: detail.join(', '),
        point: point,
        extent: extent is List && extent.length == 4
            ? _bounds([for (final v in extent) (v as num).toDouble()])
            : null,
      ),
    );
  }
  return places;
}

/// Photon documents [west, north, east, south]; order the corners defensively.
Bounds _bounds(List<double> e) => Bounds(
  math.min(e[0], e[2]),
  math.min(e[1], e[3]),
  math.max(e[0], e[2]),
  math.max(e[1], e[3]),
);
