import '../domain/app_message.dart';
import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/shared_trails.dart';

/// Trails every walker shared, opened and reviewed from the map. Personal
/// walks, speeds and statistics never leave the private library.
class CollaborativeTrails {
  const CollaborativeTrails(
    this.store,
    this.transport,
    this.repository, {
    required this.newId,
  });
  final SharedTrailStore store;
  final SharedTrailTransport transport;
  final TrailRepository repository;

  /// Identifier of a new place, chosen on the phone so retries are idempotent.
  final String Function() newId;

  Future<List<TrailPlace>> places() => store.places();

  /// Add a place on [trail] where the walker stands. It is saved on the phone
  /// at once and shared on the next sync, offline included.
  Future<TrailPlace> addPlace(
    Trail trail,
    GeoPoint position,
    String name,
    String comment,
  ) async {
    final place = TrailPlace(
      id: newId(),
      trailId: trail.sharedId,
      point: position,
      name: name.trim(),
      comment: comment.trim(),
      mine: true,
      updatedAt: DateTime.now().toUtc(),
      pending: true,
    );
    _validate(place);
    await store.savePlace(place);
    return place;
  }

  Future<void> editPlace(TrailPlace place, String name, String comment) async {
    final edited = place.edited(
      name.trim(),
      comment.trim(),
      DateTime.now().toUtc(),
    );
    _validate(edited);
    await store.savePlace(edited);
  }

  Future<void> removePlace(TrailPlace place) => store.removePlace(place);

  static void _validate(TrailPlace place) {
    if (!place.mine ||
        place.name.isEmpty ||
        place.name.length > maximumPlaceNameLength ||
        place.comment.length > maximumReviewLength) {
      throw MessageFailure(AppMessage.invalidPlace);
    }
  }

  Future<List<SharedTrail>> catalogue() => store.all();

  /// Download a shared trail once; it then stays usable offline.
  Future<Trail> open(String id) async {
    final Trail trail;
    try {
      trail = await transport.download(id);
    } on MessageFailure {
      rethrow;
    } catch (_) {
      throw MessageFailure(AppMessage.sharedTrailUnavailable);
    }
    await repository.keep(trail);
    return trail;
  }

  /// Latest reviews, or this phone's last copy while offline.
  Future<TrailReviews> reviews(String id) async {
    try {
      final reviews = await transport.reviews(id);
      await store.keepReviews(reviews);
      return reviews;
    } on RemoteFailure catch (e) {
      // Added on this phone and not synced yet: nobody reviewed it.
      if (e.status == 404) {
        return TrailReviews(
          trailId: id,
          count: 0,
          reviews: const [],
          canReview: false,
        );
      }
      return _cached(id);
    } on MessageFailure {
      rethrow;
    } catch (_) {
      return _cached(id);
    }
  }

  Future<TrailReviews> _cached(String id) async {
    final cached = await store.reviews(id);
    if (cached == null) throw MessageFailure(AppMessage.reviewsUnavailable);
    return cached.offline();
  }

  Future<TrailReviews> review(String id, int rating, String comment) async {
    final text = comment.trim();
    if (rating < 1 || rating > 5 || text.length > maximumReviewLength) {
      throw MessageFailure(AppMessage.invalidReview);
    }
    final reviews = await transport.review(id, rating, text);
    await store.keepReviews(reviews);
    return reviews;
  }

  Future<TrailReviews> removeReview(String id) async {
    final reviews = await transport.removeReview(id);
    await store.keepReviews(reviews);
    return reviews;
  }
}
