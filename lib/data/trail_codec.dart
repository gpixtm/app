import '../domain/app_message.dart';

import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../domain/models.dart';
import '../domain/day_plan.dart';
import '../domain/walk_recording.dart';
import '../domain/health_data.dart';
import '../domain/ports.dart';
import 'gpx_text.dart';

class XmlGpxDecoder implements GpxDecoder {
  XmlGpxDecoder({this.placesName});
  final String Function(String)? placesName;
  @override
  List<Trail> decode(String source, String name) {
    if (source.length > 50 * 1024 * 1024) {
      throw MessageFormatException(AppMessage.gpxTooLarge);
    }
    if (source.contains('<!DOCTYPE') || source.contains('<!ENTITY')) {
      throw MessageFormatException(AppMessage.xmlEntitiesForbidden);
    }
    final root = XmlDocument.parse(source).rootElement;
    if (root.name.local != 'gpx') {
      throw MessageFormatException(AppMessage.notGpx);
    }
    Iterable<XmlElement> children(XmlElement e, String tag) =>
        e.childElements.where((x) => x.name.local == tag);
    String text(XmlElement e, String tag) =>
        checkedGpxText(children(e, tag).firstOrNull?.innerText.trim() ?? '');
    GeoPoint point(XmlElement e) {
      final p = GeoPoint(
        double.parse(e.getAttribute('lat') ?? ''),
        double.parse(e.getAttribute('lon') ?? ''),
        double.tryParse(text(e, 'ele')),
      );
      if (!p.valid || (p.elevation != null && !p.elevation!.isFinite)) {
        throw MessageFormatException(AppMessage.invalidGpxCoordinates);
      }
      return p;
    }

    final pois = children(
      root,
      'wpt',
    ).map((e) => Poi(point(e), text(e, 'name'), text(e, 'desc'))).toList();
    final result = <Trail>[];
    for (final e in root.childElements.where(
      (e) => ['trk', 'rte'].contains(e.name.local),
    )) {
      final segments = e.name.local == 'trk'
          ? children(e, 'trkseg')
                .map((s) => children(s, 'trkpt').map(point).toList())
                .where((s) => s.isNotEmpty)
                .toList()
          : [children(e, 'rtept').map(point).toList()];
      if (segments.every((s) => s.isEmpty)) continue;
      result.add(
        Trail(
          id: const Uuid().v4(),
          name: text(e, 'name').isEmpty
              ? checkedGpxText(name)
              : text(e, 'name'),
          description: text(e, 'desc'),
          segments: segments,
          pois: const [],
        ),
      );
    }
    // Waypoints have their own identity: a multi-track import never duplicates them.
    if (pois.isNotEmpty) {
      result.add(
        Trail(
          id: const Uuid().v4(),
          name: placesName?.call(checkedGpxText(name)) ?? checkedGpxText(name),
          segments: const [],
          pois: pois,
        ),
      );
    }
    if (result.isEmpty) {
      throw MessageFormatException(AppMessage.emptyGpx);
    }
    return result;
  }
}

class TrailCodec {
  static List<num?> _point(GeoPoint p) => [p.lat, p.lon, p.elevation];
  static GeoPoint _read(List<dynamic> a) => GeoPoint(
    (a[0] as num).toDouble(),
    (a[1] as num).toDouble(),
    (a[2] as num?)?.toDouble(),
  );
  static Map<String, dynamic> encode(Trail t) => {
    'id': t.id,
    'name': t.name,
    'description': t.description,
    'estimated': t.estimated,
    if (t.walk case final walk?)
      'walk': {
        'started': walk.started.toUtc().toIso8601String(),
        'ended': walk.ended?.toUtc().toIso8601String(),
        'seconds': walk.seconds,
        'sourceTrailId': walk.sourceTrailId,
        'routeId': ?walk.routeId,
        'samples': [
          for (final s in walk.samples)
            [
              s.time.toUtc().toIso8601String(),
              s.point.lat,
              s.point.lon,
              s.point.elevation,
              s.accuracy,
              s.segment,
            ],
        ],
        if (walk.reference case final reference?)
          'reference': {
            'name': reference.name,
            'segments': [
              for (final segment in reference.segments)
                segment.map(_point).toList(),
            ],
          },
        if (walk.health case final health?)
          'health': {
            'readAt': health.readAt.toUtc().toIso8601String(),
            'sources': health.sources,
            'steps': health.steps,
            'activeCalories': health.activeCalories,
            'averageHeartRate': health.averageHeartRate,
            'maxHeartRate': health.maxHeartRate,
          },
      },
    'days': [
      for (final day in t.days) [day.start, day.end],
    ],
    'segments': t.segments.map((s) => s.map(_point).toList()).toList(),
    'pois': t.pois
        .map(
          (p) => {
            'point': _point(p.point),
            'name': p.name,
            'description': p.description,
          },
        )
        .toList(),
  };
  static Trail decode(Map<String, dynamic> j) => Trail(
    id: j['id'],
    name: j['name'],
    description: j['description'] ?? '',
    estimated: j['estimated'] ?? false,
    walk: j['walk'] == null
        ? null
        : WalkDetails(
            started: DateTime.parse(j['walk']['started']),
            ended: j['walk']['ended'] == null
                ? null
                : DateTime.parse(j['walk']['ended']),
            seconds: j['walk']['seconds'] as int,
            sourceTrailId: j['walk']['sourceTrailId'] as String?,
            routeId: j['walk']['routeId'] as String?,
            samples: [
              for (final s in (j['walk']['samples'] as List? ?? []))
                WalkSample(
                  DateTime.parse(s[0]),
                  GeoPoint(
                    (s[1] as num).toDouble(),
                    (s[2] as num).toDouble(),
                    (s[3] as num?)?.toDouble(),
                  ),
                  (s[4] as num).toDouble(),
                  s[5] as int,
                ),
            ],
            health: _health(j['walk']['health']),
            reference: _reference(j['walk']['reference']),
          ),
    days: [
      for (final day in (j['days'] as List? ?? []))
        WalkingDay((day[0] as num).toDouble(), (day[1] as num).toDouble()),
    ],
    segments: (j['segments'] as List)
        .map((s) => (s as List).map((p) => _read(p)).toList())
        .toList(),
    pois: (j['pois'] as List)
        .map((p) => Poi(_read(p['point']), p['name'], p['description']))
        .toList(),
  );
  static WalkReference? _reference(dynamic value) => value == null
      ? null
      : WalkReference(value['name'] as String, [
          for (final segment in value['segments'] as List)
            [for (final p in segment as List) _read(p)],
        ]);
  static HealthSummary? _health(dynamic value) => value == null
      ? null
      : HealthSummary(
          readAt: DateTime.parse(value['readAt']),
          sources: List<String>.from(value['sources']),
          steps: value['steps'] as int?,
          activeCalories: (value['activeCalories'] as num?)?.toDouble(),
          averageHeartRate: (value['averageHeartRate'] as num?)?.toDouble(),
          maxHeartRate: (value['maxHeartRate'] as num?)?.toDouble(),
        );
}
