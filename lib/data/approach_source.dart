import '../domain/app_message.dart';

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/approach.dart';
import '../domain/models.dart';
import '../domain/trail_geometry.dart';
import 'server_connection.dart';

class ApiApproachSource implements ApproachSource {
  const ApiApproachSource(
    this.server,
    this.db, {
    this.languageCode,
    this.routeName,
  });
  final ServerConnection server;
  final Database db;
  final String Function()? languageCode;
  final String Function(String)? routeName;
  @override
  Future<ApproachRoute> calculate(
    GeoPoint origin,
    Trail target,
    GeoPoint end,
  ) async {
    final language = languageCode?.call() ?? 'en';
    final key = 'approach-nearest:$language:${target.id}';
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(
        await server.request(
          '/api/approach',
          body: {
            'origin': [origin.lat, origin.lon],
            'destination': [end.lat, end.lon],
            'language': language,
          },
        ),
      );
      data['destination'] = [end.lat, end.lon];
    } catch (_) {
      var rows = await db.query('settings', where: 'key=?', whereArgs: [key]);
      // Releases before locale selection always requested French instructions.
      if (rows.isEmpty && language == 'fr') {
        rows = await db.query(
          'settings',
          where: 'key=?',
          whereArgs: ['approach-nearest:${target.id}'],
        );
      }
      if (rows.isNotEmpty) {
        final stored =
            jsonDecode(rows.single['value'] as String) as Map<String, dynamic>;
        final destination = stored['destination'] as List;
        final savedEnd = GeoPoint(
          (destination[0] as num).toDouble(),
          (destination[1] as num).toDouble(),
        );
        final saved = decodeApproach(
          stored,
          target,
          cached: true,
          name: routeName?.call(target.name),
        );
        final hit = TrailGeometry(saved.trail).project(origin);
        if (hit != null &&
            distance(savedEnd, end) <= 50 &&
            hit.offTrail <= 50 &&
            distance(saved.trail.points.last, end) <= 100) {
          return saved;
        }
      }
      throw MessageFailure(AppMessage.approachUnavailable);
    }
    final route = decodeApproach(
      data,
      target,
      name: routeName?.call(target.name),
    );
    if (distance(route.trail.points.first, origin) > 100 ||
        distance(route.trail.points.last, end) > 100) {
      throw MessageFailure(AppMessage.noNearbyPath);
    }
    await db.insert('settings', {
      'key': key,
      'value': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return route;
  }
}

ApproachRoute decodeApproach(
  Map<String, dynamic> data,
  Trail target, {
  bool cached = false,
  String? name,
}) {
  final shape = data['shape'] as String;
  if (shape.length > 2000000) {
    throw MessageFormatException(AppMessage.routeTooLong);
  }
  final points = <GeoPoint>[];
  var offset = 0, lat = 0, lon = 0;
  int delta() {
    var bits = 0, shift = 0, byte = 0;
    do {
      if (offset >= shape.length || shift > 30) {
        throw MessageFormatException(AppMessage.invalidGeometry);
      }
      byte = shape.codeUnitAt(offset++) - 63;
      if (byte < 0 || byte > 63) {
        throw MessageFormatException(AppMessage.invalidGeometry);
      }
      bits |= (byte & 31) << shift;
      shift += 5;
    } while (byte >= 32);
    return bits.isOdd ? ~(bits >> 1) : bits >> 1;
  }

  final offsets = <double>[];
  var length = 0.0;
  while (offset < shape.length) {
    lat += delta();
    lon += delta();
    final p = GeoPoint(lat / 1e6, lon / 1e6);
    if (!p.valid) throw MessageFormatException(AppMessage.invalidCoordinates);
    if (points.isNotEmpty) length += distance(points.last, p);
    points.add(p);
    offsets.add(length);
  }
  if (points.length < 2 || length < 1) {
    throw MessageFormatException(AppMessage.emptyRoute);
  }
  final steps = <DirectionStep>[];
  for (final s in data['steps'] as List) {
    final index = s['index'] as int;
    final instruction = s['instruction'] as String;
    if (index < 0 ||
        index >= points.length ||
        instruction.isEmpty ||
        (steps.isNotEmpty && offsets[index] < steps.last.along)) {
      throw MessageFormatException(AppMessage.invalidDirections);
    }
    steps.add(DirectionStep(offsets[index], instruction));
  }
  final seconds = (data['seconds'] as num).toDouble();
  if (steps.isEmpty || !seconds.isFinite || seconds < 0) {
    throw MessageFormatException(AppMessage.missingDirections);
  }
  return ApproachRoute(
    Trail(
      id: 'approach-${target.id}',
      name: name ?? target.name,
      segments: [points],
      pois: [],
    ),
    steps,
    seconds,
    cached: cached,
  );
}
