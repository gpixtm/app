import '../domain/catalogue.dart';
import '../domain/models.dart';
import '../domain/shared_trails.dart';

/// JSON of the API's catalogue: map areas, search pages, trail details and
/// groups. Details kept for an offline trail use the same shape.
class CatalogueCodec {
  static Bounds? _bounds(dynamic value) => value is List && value.length == 4
      ? Bounds(
          (value[1] as num).toDouble(),
          (value[0] as num).toDouble(),
          (value[3] as num).toDouble(),
          (value[2] as num).toDouble(),
        )
      : null;

  static SharedTrail trail(Map<String, dynamic> j) => SharedTrail(
    id: j['id'] as String,
    fingerprint: j['fingerprint'] as String?,
    name: j['name'] as String,
    author: j['author'] as String?,
    metres: (j['metres'] as num).toDouble(),
    outline: [
      for (final line in j['outline'] as List? ?? const [])
        [
          for (final p in line as List)
            GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
    ],
    reviews: j['reviews'] as int? ?? 0,
    average: (j['average'] as num?)?.toDouble(),
    change: j['change'] as int? ?? 0,
    source: j['source'] as String? ?? walkerSource,
    ref: j['ref'] as String?,
    bounds: _bounds(j['bounds']),
  );

  static TrailGroupSummary group(Map<String, dynamic> j) => TrailGroupSummary(
    id: j['id'] as String,
    kind: j['kind'] == 'itinerary'
        ? TrailGroupKind.itinerary
        : TrailGroupKind.collection,
    name: j['name'] as String,
    editorial: j['editorial'] as String?,
    ref: j['ref'] as String?,
    metres: (j['metres'] as num? ?? 0).toDouble(),
    trailCount: j['trailCount'] as int? ?? 0,
    bounds: _bounds(j['bounds']),
    source: j['source'] as String? ?? walkerSource,
    author: j['author'] as String?,
    mine: j['mine'] as bool? ?? false,
  );

  static CatalogueArea area(Map<String, dynamic> j) => CatalogueArea([
    for (final t in j['trails'] as List) trail(_map(t)),
  ], j['truncated'] as bool? ?? false);

  static CataloguePage page(Map<String, dynamic> j) => CataloguePage([
    for (final raw in j['items'] as List) ?_item(_map(raw)),
  ], j['next'] as String?);

  /// Unknown kinds from a newer API are skipped.
  static CatalogueItem? _item(Map<String, dynamic> j) => switch (j['type']) {
    'group' => CatalogueGroupItem(group(_map(j['group']))),
    'trail' => CatalogueTrailItem(trail(_map(j['trail']))),
    _ => null,
  };

  static MemberRole role(Object? value) => MemberRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => MemberRole.main,
  );

  /// Details of a trail page (`GET /api/public-trails/{id}`) or a group page.
  static TrailDetails details(Map<String, dynamic> j) {
    final source = _map(j['details'] ?? const {});
    final osm = source['osm'] is Map ? _map(source['osm']) : null;
    return TrailDetails(
      source: j['source'] as String? ?? walkerSource,
      licence: j['licence'] as String?,
      attribution: j['attribution'] as String?,
      fields: {
        for (final MapEntry(:key, :value) in source.entries)
          if (value is String) key: value,
      },
      descriptions: {
        for (final MapEntry(:key, :value) in _map(
          source['descriptions'] ?? const {},
        ).entries)
          if (value is String) key: value,
      },
      roundtrip: source['roundtrip'] as bool?,
      pilgrimage: source['pilgrimage'] == true,
      osmType: osm?['type'] as String?,
      osmId: osm?['id'] as int?,
      author: j['author'] as String?,
      metres: (j['metres'] as num?)?.toDouble(),
      reviews: j['reviews'] as int? ?? 0,
      average: (j['average'] as num?)?.toDouble(),
      hidden: j['hidden'] as bool? ?? false,
      paths: [
        for (final p in j['groups'] as List? ?? const [])
          TrailGroupPath(
            [for (final g in _map(p)['groups'] as List) group(_map(g))],
            role(_map(p)['role']),
            stage: _map(p)['stage'] as int?,
          ),
      ],
    );
  }

  static Map<String, dynamic> encodeDetails(TrailDetails d) => {
    'source': d.source,
    'licence': d.licence,
    'attribution': d.attribution,
    'author': d.author,
    'metres': d.metres,
    'reviews': d.reviews,
    'average': d.average,
    'hidden': d.hidden,
    'details': {
      ...d.fields,
      if (d.descriptions.isNotEmpty) 'descriptions': d.descriptions,
      'roundtrip': ?d.roundtrip,
      if (d.pilgrimage) 'pilgrimage': true,
      if (d.osmId != null) 'osm': {'type': d.osmType, 'id': d.osmId},
    },
    'groups': [
      for (final path in d.paths)
        {
          'groups': [for (final g in path.groups) encodeGroup(g)],
          'role': path.role.name,
          'stage': path.stage,
        },
    ],
  };

  static Map<String, dynamic> encodeGroup(TrailGroupSummary g) => {
    'id': g.id,
    'kind': g.kind.name,
    'name': g.name,
    'editorial': g.editorial,
    'ref': g.ref,
    'metres': g.metres,
    'trailCount': g.trailCount,
    'bounds': g.bounds == null
        ? null
        : [g.bounds!.south, g.bounds!.west, g.bounds!.north, g.bounds!.east],
    'source': g.source,
    'author': g.author,
    'mine': g.mine,
  };

  static TrailGroup fullGroup(Map<String, dynamic> j) => TrailGroup(
    summary: group(j),
    description: j['description'] as String? ?? '',
    details: details(j),
    parents: [
      for (final p in j['parents'] as List? ?? const []) group(_map(p)),
    ],
    members: [for (final m in j['members'] as List) _member(_map(m))],
  );

  /// A group as [fullGroup] reads it, to keep an itinerary's stages on the
  /// phone for walking it offline.
  static Map<String, dynamic> encodeFullGroup(TrailGroup g) => {
    ...encodeDetails(g.details),
    ...encodeGroup(g.summary),
    'description': g.description,
    'parents': [for (final p in g.parents) encodeGroup(p)],
    'members': [
      for (final m in g.members)
        {
          'role': m.role.name,
          'stage': m.stage,
          if (m.trail case final trail?) ...{
            'type': 'trail',
            'trail': encodeTrail(trail),
          } else if (m.group case final group?) ...{
            'type': 'group',
            'group': encodeGroup(group),
          },
        },
    ],
  };

  static Map<String, dynamic> encodeTrail(SharedTrail t) => {
    'id': t.id,
    'fingerprint': t.fingerprint,
    'name': t.name,
    'author': t.author,
    'metres': t.metres,
    'outline': [
      for (final line in t.outline)
        [
          for (final p in line) [p.lat, p.lon],
        ],
    ],
    'reviews': t.reviews,
    'average': t.average,
    'change': t.change,
    'source': t.source,
    'ref': t.ref,
    'bounds': t.bounds == null
        ? null
        : [t.bounds!.south, t.bounds!.west, t.bounds!.north, t.bounds!.east],
  };

  static TrailGroupMember _member(Map<String, dynamic> m) => TrailGroupMember(
    role(m['role']),
    stage: m['stage'] as int?,
    trail: m['type'] == 'trail' ? trail(_map(m['trail'])) : null,
    group: m['type'] == 'group' ? group(_map(m['group'])) : null,
  );

  static Map<String, dynamic> encodeDraft(GroupDraft d) => {
    'kind': d.kind.name,
    'name': d.name,
    'description': d.description,
    'members': [
      for (final m in d.members)
        {'trailId': ?m.trailId, 'groupId': ?m.groupId, 'role': ?m.role?.name},
    ],
  };

  static Map<String, dynamic> _map(Object? value) =>
      (value as Map).cast<String, dynamic>();
}
