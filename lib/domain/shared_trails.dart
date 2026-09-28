import 'models.dart';

/// Offline catalogue entry of a trail any walker shared. It carries a light
/// outline so the map can pin it before the full trail is downloaded.
class SharedTrail {
  const SharedTrail({
    required this.id,
    required this.fingerprint,
    required this.name,
    required this.metres,
    required this.outline,
    required this.change,
    this.author,
    this.reviews = 0,
    this.average,
  });
  final String id, fingerprint, name;

  /// Username of the walker who shared it; null once that account is gone.
  final String? author;
  final double metres;
  final List<List<GeoPoint>> outline;
  final int reviews, change;
  final double? average;

  /// Map preview: pinned like any trail, replaced by the full trail on open.
  Trail get preview =>
      Trail(id: id, name: name, segments: outline, pois: const []);
}

class SharedTrailPage {
  const SharedTrailPage(this.trails, this.next, this.more);
  final List<SharedTrail> trails;
  final int next;
  final bool more;
}

class TrailReview {
  const TrailReview({
    required this.rating,
    required this.comment,
    required this.updatedAt,
    required this.mine,
    this.author,
  });
  final String? author;
  final int rating;
  final String comment;
  final DateTime updatedAt;
  final bool mine;
}

/// Reviews of one shared trail, as last read from the server.
class TrailReviews {
  const TrailReviews({
    required this.trailId,
    required this.count,
    required this.reviews,
    required this.canReview,
    this.average,
    this.completion,
    this.cached = false,
  });
  final String trailId;
  final int count;
  final double? average;

  /// Best share of the trail one of the walker's synced walks covered.
  final double? completion;

  /// Reviewing requires one recorded walk covering at least 90 % of the trail;
  /// the API enforces it.
  final bool canReview;
  final List<TrailReview> reviews;

  /// Read from this phone's copy because the server was unreachable.
  final bool cached;
  TrailReview? get mine => reviews.where((r) => r.mine).firstOrNull;
  TrailReviews offline() => TrailReviews(
    trailId: trailId,
    count: count,
    reviews: reviews,
    canReview: canReview,
    average: average,
    completion: completion,
    cached: true,
  );
}

const maximumReviewLength = 2000;

/// A place a walker added on a shared trail from where they stood, such as a
/// viewpoint or a spring. Shared with everyone; only its author changes it.
class TrailPlace {
  const TrailPlace({
    required this.id,
    required this.trailId,
    required this.point,
    required this.name,
    required this.mine,
    required this.updatedAt,
    this.comment = '',
    this.author,
    this.deleted = false,
    this.change = 0,
    this.pending = false,
  });
  final String id, trailId, name, comment;
  final GeoPoint point;
  final String? author;
  final bool mine, deleted;
  final DateTime updatedAt;
  final int change;

  /// Saved on this phone, waiting for a connection to be shared.
  final bool pending;
  Poi get poi => Poi(point, name, comment);
  TrailPlace edited(String name, String comment, DateTime now) => TrailPlace(
    id: id,
    trailId: trailId,
    point: point,
    name: name,
    comment: comment,
    mine: mine,
    updatedAt: now,
    author: author,
    change: change,
    pending: true,
  );
}

/// A place belongs to the trail it is added on: the walker stands this close.
const maximumPlaceDistance = 100.0;
const maximumPlaceNameLength = 200;

class TrailPlacePage {
  const TrailPlacePage(this.places, this.next, this.more);
  final List<TrailPlace> places;
  final int next;
  final bool more;
}

/// A local place change still to send; [version] detects a newer local edit.
class PendingPlace {
  const PendingPlace(this.place, this.delete, this.version);
  final TrailPlace place;
  final bool delete;
  final int version;
}

abstract interface class SharedTrailStore {
  Future<int> cursor();

  /// Store one index page and its cursor together.
  Future<void> apply(SharedTrailPage page);
  Future<List<SharedTrail>> all();
  Future<TrailReviews?> reviews(String trailId);
  Future<void> keepReviews(TrailReviews reviews);

  Future<int> placeCursor();

  /// Store one page of places and its cursor; local changes not yet sent win.
  Future<void> applyPlaces(TrailPlacePage page);

  /// Visible places, local changes included.
  Future<List<TrailPlace>> places();

  /// Queue a new or edited place of this walker, durably, even offline.
  Future<void> savePlace(TrailPlace place);
  Future<void> removePlace(TrailPlace place);

  /// Queued changes, their trail resolved to the shared trail it now links to.
  Future<List<PendingPlace>> pendingPlaces();

  /// The server accepted [sent] ([result] is null after a refusal).
  Future<void> placeSent(PendingPlace sent, TrailPlace? result);
}

abstract interface class SharedTrailTransport {
  Future<SharedTrailPage> index(int since);

  /// The full shared trail, kept on the phone once downloaded.
  Future<Trail> download(String id);
  Future<TrailReviews> reviews(String id);
  Future<TrailReviews> review(String id, int rating, String comment);
  Future<TrailReviews> removeReview(String id);
  Future<TrailPlacePage> places(int since);
  Future<TrailPlace> savePlace(TrailPlace place);
  Future<TrailPlace> removePlace(TrailPlace place);
}
