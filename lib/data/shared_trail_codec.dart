import '../domain/models.dart';
import '../domain/shared_trails.dart';

/// JSON of the API's shared trail catalogue and reviews. The phone stores the
/// same shape so its offline copy reads exactly like a server response.
class SharedTrailCodec {
  static SharedTrail decode(Map<String, dynamic> j) => SharedTrail(
    id: j['id'] as String,
    fingerprint: j['fingerprint'] as String,
    name: j['name'] as String,
    author: j['author'] as String?,
    metres: (j['metres'] as num).toDouble(),
    outline: [
      for (final line in j['outline'] as List)
        [
          for (final p in line as List)
            GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
    ],
    reviews: j['reviews'] as int? ?? 0,
    average: (j['average'] as num?)?.toDouble(),
    change: j['change'] as int,
  );

  static Map<String, dynamic> encode(SharedTrail t) => {
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
  };

  static SharedTrailPage decodePage(Map<String, dynamic> j) => SharedTrailPage(
    [
      for (final t in j['trails'] as List)
        decode((t as Map).cast<String, dynamic>()),
    ],
    j['next'] as int,
    j['more'] as bool,
  );

  static TrailPlace decodePlace(
    Map<String, dynamic> j, {
    bool pending = false,
  }) => TrailPlace(
    id: j['id'] as String,
    trailId: j['trailId'] as String,
    point: GeoPoint(
      (j['lat'] as num).toDouble(),
      (j['lon'] as num).toDouble(),
      (j['elevation'] as num?)?.toDouble(),
    ),
    name: j['name'] as String,
    comment: j['comment'] as String? ?? '',
    author: j['author'] as String?,
    mine: j['mine'] as bool,
    deleted: j['deleted'] as bool? ?? false,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    change: j['change'] as int? ?? 0,
    pending: pending,
  );

  static Map<String, dynamic> encodePlace(TrailPlace p) => {
    'id': p.id,
    'trailId': p.trailId,
    'lat': p.point.lat,
    'lon': p.point.lon,
    'elevation': p.point.elevation,
    'name': p.name,
    'comment': p.comment,
    'author': p.author,
    'mine': p.mine,
    'deleted': p.deleted,
    'updatedAt': p.updatedAt.toUtc().toIso8601String(),
    'change': p.change,
  };

  static TrailPlacePage decodePlaces(Map<String, dynamic> j) => TrailPlacePage(
    [
      for (final p in j['places'] as List)
        decodePlace((p as Map).cast<String, dynamic>()),
    ],
    j['next'] as int,
    j['more'] as bool,
  );

  static TrailReviews decodeReviews(Map<String, dynamic> j) => TrailReviews(
    trailId: j['trailId'] as String,
    count: j['count'] as int,
    average: (j['average'] as num?)?.toDouble(),
    completion: (j['completion'] as num?)?.toDouble(),
    canReview: j['canReview'] as bool,
    reviews: [
      for (final r in j['reviews'] as List)
        TrailReview(
          author: r['author'] as String?,
          rating: r['rating'] as int,
          comment: r['comment'] as String,
          updatedAt: DateTime.parse(r['updatedAt'] as String),
          mine: r['mine'] as bool,
        ),
    ],
  );

  static Map<String, dynamic> encodeReviews(TrailReviews r) => {
    'trailId': r.trailId,
    'count': r.count,
    'average': r.average,
    'completion': r.completion,
    'canReview': r.canReview,
    'reviews': [
      for (final review in r.reviews)
        {
          'author': review.author,
          'rating': review.rating,
          'comment': review.comment,
          'updatedAt': review.updatedAt.toUtc().toIso8601String(),
          'mine': review.mine,
        },
    ],
  };
}
