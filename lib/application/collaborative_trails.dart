import '../domain/app_message.dart';
import '../domain/catalogue.dart';
import '../domain/models.dart';
import '../domain/point_attachment.dart';
import '../domain/ports.dart';
import '../domain/shared_trails.dart';

/// Places shared by attaching points files, and those files as they were.
class AttachedPoints {
  const AttachedPoints(this.places, this.sources);
  final List<TrailPlace> places;
  final List<Trail> sources;
}

/// Trails every walker shared and trails from open data, browsed from the map
/// and the catalogue, opened, reviewed and grouped. Personal walks, speeds and
/// statistics never leave the private library.
class CollaborativeTrails {
  const CollaborativeTrails(
    this.store,
    this.transport,
    this.repository, {
    required this.newId,
    this.catalogue,
  });
  final SharedTrailStore store;
  final SharedTrailTransport transport;
  final TrailRepository repository;

  /// The server's catalogue, browsed without copying it to the phone.
  final CatalogueTransport? catalogue;

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

  /// Share the points of [plan] as places of their trails, offline included.
  /// The points left out stay in their file; a file left empty leaves the
  /// library. Returns what [detachPoints] needs to undo it.
  Future<AttachedPoints> attachPoints(PointAttachment plan) async {
    final now = DateTime.now().toUtc();
    final places = [
      for (final p in plan.added)
        TrailPlace(
          id: newId(),
          trailId: p.trail!.sharedId,
          point: p.poi.point,
          name: p.name,
          comment: p.comment,
          mine: true,
          updatedAt: now,
          pending: true,
          origin: PlaceOrigin.imported,
        ),
    ];
    places.forEach(_validate);
    await store.attachPoints(
      places,
      remaining: plan.remaining,
      emptied: plan.emptied,
    );
    return AttachedPoints(places, plan.sources);
  }

  /// Withdraw the places [attached] shared and restore their files.
  Future<void> detachPoints(AttachedPoints attached) =>
      store.detachPoints(attached.places, attached.sources);

  static void _validate(TrailPlace place) {
    if (!place.mine ||
        place.name.isEmpty ||
        place.name.length > maximumPlaceNameLength ||
        place.comment.length > maximumReviewLength) {
      throw MessageFailure(AppMessage.invalidPlace);
    }
  }

  CatalogueTransport get _catalogue =>
      catalogue ?? (throw MessageFailure(AppMessage.sharedTrailUnavailable));

  /// Catalogue trails in a map area; never stored on the phone.
  Future<CatalogueArea> area(Bounds view) => _catalogue.area(view);

  Future<CataloguePage> search(String query, {String? cursor}) =>
      _catalogue.search(query.trim(), cursor: cursor);

  /// A full trail and its details, from the server. Offline, a trail made
  /// available offline ([local]) opens from the phone's copy.
  Future<CatalogueTrail> open(String id, {Trail? local}) async {
    try {
      return await _catalogue.trail(id);
    } on MessageFailure {
      rethrow;
    } catch (_) {
      if (local != null) {
        return CatalogueTrail(
          local,
          await store.details(id) ?? TrailDetails.walker,
        );
      }
      throw MessageFailure(AppMessage.sharedTrailUnavailable);
    }
  }

  /// Details kept with a trail made available offline.
  Future<TrailDetails?> localDetails(String id) => store.details(id);

  /// Store a catalogue trail and its details on the phone, for offline use.
  /// It does not become a private copy until the walker changes it.
  Future<void> keepOffline(CatalogueTrail trail) async {
    await repository.keep(trail.trail);
    await store.keepDetails(trail.trail.id, trail.details);
  }

  /// Remove a trail made available offline from the phone.
  Future<void> forget(Trail trail) async {
    await repository.delete(trail.id);
    await store.forgetDetails(trail.id);
  }

  Future<TrailGroup> group(String id) async {
    try {
      return await _catalogue.group(id);
    } on MessageFailure {
      rethrow;
    } on RemoteFailure {
      rethrow;
    } catch (_) {
      throw MessageFailure(AppMessage.catalogueUnavailable);
    }
  }

  /// An itinerary for walking its stages: read from the server and kept on
  /// the phone, or this phone's last copy while offline.
  Future<TrailGroup?> itinerary(String id) async {
    try {
      final group = await _catalogue.group(id);
      await store.keepGroup(group);
      return group;
    } on RemoteFailure catch (e) {
      if (e.status == 404) return null;
      return store.group(id);
    } catch (_) {
      return store.group(id);
    }
  }

  Future<List<TrailGroupSummary>> myGroups() => _catalogue.myGroups();

  Future<TrailGroup> saveGroup(String id, GroupDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty ||
        name.length > maximumGroupNameLength ||
        draft.members.length > maximumGroupMembers) {
      throw MessageFailure(AppMessage.invalidGroup);
    }
    return _catalogue.saveGroup(
      id,
      GroupDraft(
        kind: draft.kind,
        name: name,
        description: draft.description.trim(),
        members: draft.members,
      ),
    );
  }

  Future<void> removeGroup(String id) => _catalogue.removeGroup(id);

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
