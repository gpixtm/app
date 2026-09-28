import '../domain/app_message.dart';

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'announce_progress.dart';
import 'collaborative_trails.dart';
import 'guide_navigation.dart';
import 'library.dart';
import 'prepare_maps.dart';
import 'record_walk.dart';
import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/trail_geometry.dart';
import '../domain/coverage.dart';
import '../domain/connection_settings.dart';
import '../domain/day_plan.dart';
import '../domain/health_data.dart';
import '../domain/approach.dart';
import '../domain/catalogue.dart';
import '../domain/place_search.dart';
import '../domain/point_attachment.dart';
import '../domain/shared_trails.dart';
import '../domain/stages.dart';
import '../domain/trail_statistics.dart';
import '../domain/walk_energy.dart';
import '../domain/walk_recap.dart';
import '../domain/walked_route.dart';

class AppController {
  AppController({
    required this.library,
    required this.maps,
    required this.gps,
    required this.sync,
    required this.setAwake,
    required this.vibrate,
    this.loadDemo,
    this.connectionDetails,
    this.automaticMaps,
    this.recorder,
    this.health,
    this.approachSource,
    this.guide,
    this.saveVoiceGuidance,
    this.placeSearch,
    this.recap,
    this.statistics,
    this.saveSpokenRecap,
    this.collaborative,
    this.profiles,
    this.saveShareWithHealth,
    this.shareWithHealth = false,
  });

  /// Walker weight and pack for calorie estimates (account data).
  final ProfileStore? profiles;
  WalkerProfile walker = const WalkerProfile();

  /// Latest weight another app wrote to Health Connect; used only while the
  /// profile has none, and never copied into the account.
  double? healthWeightKg;

  /// Moved mass for calories: own weight, else Health Connect's, plus pack.
  double? get massKg {
    final weight = walker.weightKg ?? healthWeightKg;
    return weight == null ? null : weight + (walker.packKg ?? 0);
  }

  Future<void> _loadProfile() async {
    if (profiles == null) return;
    try {
      walker = (await profiles!.read()).profile;
      recorder?.massKg = massKg;
    } catch (_) {}
  }

  Future<void> refreshHealthWeight() async {
    if (health == null) return;
    try {
      final weight = await health!.latestWeight();
      healthWeightKg = weight != null && WalkerProfile.validWeight(weight)
          ? weight
          : null;
    } catch (_) {
      return;
    }
    if (_disposed) return;
    recorder?.massKg = massKg;
    notifyListeners();
  }

  /// Device preference: Health Connect permissions belong to this phone.
  bool shareWithHealth;
  final Future<void> Function(bool)? saveShareWithHealth;
  Future<void> setShareWithHealth(bool enabled) async {
    if (health == null) return;
    if (enabled) {
      try {
        var status = await health!.sharingStatus();
        if (status == HealthAvailability.needsPermission) {
          status = await health!.authorizeSharing();
        }
        if (status != HealthAvailability.connected) {
          message = status == HealthAvailability.needsPermission
              ? AppMessage.healthSharePermission
              : AppMessage.healthShareFailed;
          notifyListeners();
          return;
        }
      } catch (_) {
        message = AppMessage.healthShareFailed;
        notifyListeners();
        return;
      }
    }
    shareWithHealth = enabled;
    notifyListeners();
    try {
      await saveShareWithHealth?.call(enabled);
    } catch (_) {}
  }

  /// Send a finished walk to Health Connect; repeating it updates, never
  /// duplicates. [ask] requests the write permission when missing.
  Future<bool> _share(Trail walk, {required bool ask}) async {
    final export = HealthExport.of(walk);
    if (health == null || export == null) return false;
    var status = await health!.sharingStatus();
    if (ask && status == HealthAvailability.needsPermission) {
      status = await health!.authorizeSharing();
    }
    if (status != HealthAvailability.connected) {
      throw MessageFailure(
        status == HealthAvailability.needsPermission
            ? AppMessage.healthSharePermission
            : AppMessage.healthShareFailed,
      );
    }
    await health!.share(export);
    return true;
  }

  Future<void> shareToHealth(Trail walk) => run(() async {
    try {
      if (await _share(walk, ask: true)) message = AppMessage.healthShared;
    } on MessageFailure {
      rethrow;
    } catch (_) {
      throw MessageFailure(AppMessage.healthShareFailed);
    }
  });

  Future<void> saveProfile(WalkerProfile value) async {
    if (profiles == null ||
        !WalkerProfile.validWeight(value.weightKg) ||
        !WalkerProfile.validPack(value.packKg)) {
      return;
    }
    walker = value;
    recorder?.massKg = massKg;
    notifyListeners();
    try {
      await profiles!.save(value, pending: true);
      _scheduleSync();
    } catch (_) {
      message = AppMessage.profileNotSaved;
      notifyListeners();
    }
  }

  /// Trails every walker shared and the open-data catalogue; absent in tests
  /// and older setups.
  final CollaborativeTrails? collaborative;

  /// Catalogue trails in the visible map area, loaded from the server and
  /// never stored on the phone. Offline, the last area stays until closing.
  List<SharedTrail> area = [];
  bool areaTruncated = false;
  int _areaRequest = 0;

  /// Summaries of catalogue trails seen in areas and searches this session.
  final Map<String, SharedTrail> _summaries = {};

  /// Catalogue trails opened this session, kept in memory only.
  final Map<String, Trail> _browsed = {};

  /// Trails made available offline: kept on the phone, not the walker's own.
  Set<String> offlineCopies = {};

  /// Every trail marked by a pin: the phone's trails (imported, created, made
  /// available offline), then catalogue trails of the area not among them.
  /// A catalogue trail appears as a light preview until opened.
  List<Trail> pinned = [];
  Set<String> _previews = {};
  Set<String> _storedIds = {};

  /// A pinned catalogue trail not downloaded yet; once opened it is full.
  bool isPreview(Trail trail) =>
      _previews.contains(trail.id) && !_browsed.containsKey(trail.id);
  SharedTrail? sharedFor(Trail trail) => _summaries[trail.sharedId];

  /// On this phone: imported, created or made available offline. Other
  /// trails come from the catalogue and are drawn in its colour.
  bool stored(Trail trail) => _storedIds.contains(trail.id);
  bool isOfflineCopy(Trail trail) => offlineCopies.contains(trail.id);

  /// Load the catalogue trails of the visible map area. Only the latest
  /// request counts; a failure keeps the previous area.
  Future<void> browseArea(Bounds view) async {
    final catalogue = collaborative;
    if (catalogue?.catalogue == null || _disposed) return;
    final request = ++_areaRequest;
    try {
      final result = await catalogue!.area(view);
      if (_disposed || request != _areaRequest) return;
      area = result.trails;
      areaTruncated = result.truncated;
      if (_summaries.length > 3000) _summaries.clear();
      for (final t in area) {
        _summaries[t.id] = t;
      }
      _pin();
      notifyListeners();
    } catch (_) {
      // Offline or an older API: the phone's own trails stay pinned.
    }
  }

  void _pin() {
    final known = {
      for (final t in trails) ...[t.id, ?t.publicId],
    };
    final previews = [
      for (final s in area)
        if (!known.contains(s.id)) s.preview,
    ];
    _previews = {for (final t in previews) t.id};
    pinned = [...trails, ...previews];
  }

  /// Show a pinned trail: a catalogue preview is downloaded, then shown from
  /// memory until the walker makes it available offline or starts it.
  Future<void> open(Trail trail) async {
    if (_browsed[trail.id] case final full?) {
      focus(full);
      return;
    }
    if (!isPreview(trail) || collaborative == null) {
      focus(trail);
      return;
    }
    await openShared(trail.id);
  }

  /// Open a trail of the catalogue by identifier, from a search or a group.
  Future<void> openShared(String id) => run(() async {
    final local = trails
        .where((t) => t.id == id || t.publicId == id)
        .firstOrNull;
    if (local != null) {
      focus(local);
      return;
    }
    final full = await collaborative!.open(id);
    if (_disposed) return;
    _browsed[full.trail.id] = full.trail;
    _details[full.trail.sharedId] = full.details;
    focus(full.trail);
  });

  /// Details of the focused trail: source, description, reference, groups.
  TrailDetails? details;
  final Map<String, TrailDetails> _details = {};
  String? _detailsFor;
  Future<void> refreshDetails() async {
    final trail = focused;
    final id = trail == null || trail.walk != null || isPreview(trail)
        ? null
        : trail.sharedId;
    _detailsFor = id;
    details = id == null ? null : _details[id];
    final catalogue = collaborative;
    if (id == null || catalogue == null) return;
    if (details != null) {
      unawaited(_loadStages(trail!));
      return;
    }
    TrailDetails? result;
    try {
      result = (await catalogue.open(id)).details;
    } catch (_) {
      try {
        result = await catalogue.localDetails(id);
      } catch (_) {
        // The library closed meanwhile (account change): nothing to show.
      }
    }
    if (_disposed || _detailsFor != id || result == null) return;
    _details[id] = details = result;
    notifyListeners();
    unawaited(_loadStages(trail!));
  }

  /// Where trails are numbered stages of an itinerary, by shared identifier;
  /// null once known not to be one.
  final Map<String, StageLinks?> _stages = {};

  /// The itinerary stages before and after [trail], when it is one of them.
  StageLinks? stagesOf(Trail? trail) =>
      trail == null ? null : _stages[trail.sharedId];

  /// Find the stages around [trail] from its details and its itinerary, kept
  /// on the phone so the next stage is known offline.
  Future<StageLinks?> _loadStages(Trail trail) async {
    final catalogue = collaborative;
    final id = trail.sharedId;
    if (catalogue == null || trail.walk != null) return null;
    if (_stages.containsKey(id)) return _stages[id];
    var details = _details[id];
    if (details == null) {
      try {
        details = await catalogue.localDetails(id);
      } catch (_) {
        // The library closed meanwhile (account change).
      }
    }
    if (details == null || _disposed) return null;
    final itinerary = StageLinks.itinerary(details);
    if (itinerary == null) {
      _stages[id] = null;
      return null;
    }
    final TrailGroup? group;
    try {
      group = await catalogue.itinerary(itinerary.id);
    } catch (_) {
      return null;
    }
    if (_disposed || group == null) return null;
    final links = _stages[id] = StageLinks.of(group, id);
    notifyListeners();
    return links;
  }

  /// Open the stage [member] of an itinerary on the map, without interrupting
  /// the walk in progress.
  Future<void> openStage(TrailGroupMember member) async {
    final id = member.trail?.id;
    if (id == null) return;
    await openShared(id);
    if (!_disposed && focused?.sharedId != id && focused?.id != id) {
      message = AppMessage.stageUnavailable(member.stage ?? 0);
      notifyListeners();
    }
  }

  /// Keep [trail] and its details on the phone, with its maps.
  Future<void> makeAvailableOffline(Trail trail) => run(() async {
    await _keepOffline(trail);
    message = AppMessage.availableOffline;
  });

  Future<void> _keepOffline(Trail trail) async {
    final catalogue = collaborative;
    if (catalogue == null || stored(trail)) return;
    var details = _details[trail.sharedId];
    if (details == null) {
      try {
        details = (await catalogue.open(trail.sharedId)).details;
      } catch (_) {
        // Offline: the trail is kept without its details.
      }
    }
    await catalogue.keepOffline(
      CatalogueTrail(trail, details ?? TrailDetails.walker),
    );
    _browsed.remove(trail.id);
    await reload();
    unawaited(prepareTrailMaps([trail]));
  }

  /// Remove a trail made available offline; it stays open until closed.
  Future<void> removeOffline(Trail trail) => run(() async {
    if (!isOfflineCopy(trail) || collaborative == null) return;
    if (session?.active == true && selected?.id == trail.id) return;
    _browsed[trail.id] = trail;
    await collaborative!.forget(trail);
    await reload();
    message = AppMessage.offlineRemoved;
  });

  Future<CataloguePage> searchCatalogue(String query, {String? cursor}) =>
      collaborative?.search(query, cursor: cursor) ??
      Future.error(MessageFailure(AppMessage.catalogueUnavailable));

  /// Remember summaries of searched trails for their rating and length.
  void noteSearchResults(CataloguePage page) {
    for (final item in page.items) {
      if (item case CatalogueTrailItem(:final trail)) {
        _summaries[trail.id] = trail;
      }
    }
  }

  Future<TrailGroup> group(String id) =>
      collaborative?.group(id) ??
      Future.error(MessageFailure(AppMessage.catalogueUnavailable));

  Future<List<TrailGroupSummary>> myGroups() =>
      collaborative?.myGroups() ??
      Future.error(MessageFailure(AppMessage.catalogueUnavailable));

  /// Create or change the walker's group. Trails not synced yet are sent
  /// first: a group only holds trails the server knows.
  Future<TrailGroup?> saveGroup(String id, GroupDraft draft) async {
    TrailGroup? saved;
    await run(() async {
      if (collaborative == null) return;
      try {
        syncStatus = await sync.synchronize();
      } catch (_) {
        // Offline: saving the group reports it.
      }
      saved = await collaborative!.saveGroup(id, draft);
      message = AppMessage.groupSaved;
    });
    return saved;
  }

  /// Create a group; the phone chooses its identifier so a retry is harmless.
  Future<TrailGroup?> createGroup(GroupDraft draft) async {
    final catalogue = collaborative;
    if (catalogue == null) return null;
    return saveGroup(catalogue.newId(), draft);
  }

  /// Add [trail] at the end of the walker's [group].
  Future<void> addToGroup(TrailGroupSummary group, Trail trail) async {
    final TrailGroup current;
    try {
      current = await this.group(group.id);
    } catch (e) {
      message = e;
      notifyListeners();
      return;
    }
    if (current.trails.any((t) => t.id == trail.sharedId)) {
      message = AppMessage.addedToGroup(group.name);
      notifyListeners();
      return;
    }
    final saved = await saveGroup(
      group.id,
      GroupDraft(
        kind: current.summary.kind,
        name: current.summary.name,
        description: current.description,
        members: [
          for (final m in current.members)
            GroupMemberRef(
              trailId: m.trail?.id,
              groupId: m.group?.id,
              role: m.role,
            ),
          GroupMemberRef(trailId: trail.sharedId),
        ],
      ),
    );
    if (saved != null) message = AppMessage.addedToGroup(group.name);
    notifyListeners();
  }

  Future<bool> removeGroup(String id) async {
    var removed = false;
    await run(() async {
      await collaborative?.removeGroup(id);
      removed = true;
      message = AppMessage.groupDeleted;
    });
    return removed;
  }

  /// Make every trail of [group] available offline, with the trails of its
  /// nested groups one level down.
  Future<void> makeGroupAvailableOffline(TrailGroup group) => run(() async {
    final catalogue = collaborative;
    if (catalogue == null) return;
    final ids = <String>{for (final t in group.trails) t.id};
    for (final m in group.members) {
      if (m.group case final nested?) {
        ids.addAll((await catalogue.group(nested.id)).trails.map((t) => t.id));
      }
    }
    var done = 0;
    for (final id in ids) {
      done++;
      if (trails.any((t) => t.id == id || t.publicId == id)) continue;
      final full = await catalogue.open(id);
      _details[full.trail.sharedId] = full.details;
      await catalogue.keepOffline(full);
      _browsed.remove(full.trail.id);
      progress = done / ids.length;
      notifyListeners();
    }
    await reload();
    unawaited(
      prepareTrailMaps([
        for (final t in trails)
          if (ids.contains(t.sharedId)) t,
      ]),
    );
    message = AppMessage.groupAvailableOffline(ids.length);
  });

  /// Places walkers added on shared trails, this phone's pending ones included.
  List<TrailPlace> places = [];

  /// The trails whose points and places the map shows: the open trail, and
  /// the trail being followed while another one is browsed. Points of other
  /// trails and points files stay hidden until they are opened.
  List<Trail> get _shownTrails => [
    ?focused,
    if (selected case final followed? when followed.id != focused?.id) followed,
  ];

  /// Places of the trails the map shows.
  List<TrailPlace> get visiblePlaces {
    final ids = {
      for (final t in _shownTrails) ...[t.id, t.sharedId],
    };
    return [
      for (final p in places)
        if (ids.contains(p.trailId)) p,
    ];
  }

  /// How many places [trail] has, this phone's pending ones included.
  int placeCount(Trail trail) => places
      .where((p) => p.trailId == trail.id || p.trailId == trail.sharedId)
      .length;

  /// Add a place on [trail] where the walker stands: a fresh, precise fix
  /// within [maximumPlaceDistance] of the line, between vertices included.
  Future<void> addPlace(Trail trail, String name, String comment) =>
      run(() async {
        if (collaborative == null) return;
        final fix = await _positionForApproach();
        if (_disposed) return;
        mapFix = fix;
        final offTrail = TrailGeometry(trail).project(fix.point)?.offTrail;
        if (offTrail == null || offTrail > maximumPlaceDistance) {
          throw MessageFailure(AppMessage.placeTooFar);
        }
        await collaborative!.addPlace(trail, fix.point, name, comment);
        places = await collaborative!.places();
        message = AppMessage.placeSaved;
        _scheduleSync();
      });

  Future<void> editPlace(TrailPlace place, String name, String comment) =>
      run(() async {
        await collaborative?.editPlace(place, name, comment);
        places = await collaborative?.places() ?? const [];
        message = AppMessage.placeSaved;
        _scheduleSync();
      });

  Future<void> deletePlace(TrailPlace place) => run(() async {
    await collaborative?.removePlace(place);
    places = await collaborative?.places() ?? const [];
    message = AppMessage.placeDeleted;
    _scheduleSync();
  });

  /// Points files of the library: waypoints not attached to any trail yet.
  List<Trail> get pointsFiles => [
    for (final t in trails)
      if (!t.followable && t.pois.isNotEmpty) t,
  ];

  /// Points files being attached to a trail, previewed on the map.
  PointAttachment? attaching;

  /// Trails the points being attached may go to, most points within reach
  /// first: the library's, then shared trails around the points.
  List<AttachTarget> attachTargets = const [];

  /// The last attachment, which the walker may still undo.
  AttachedPoints? lastAttachment;

  /// Preview attaching [sources] on the map: to [targets] when given, else to
  /// the trail with most of their points within reach.
  Future<void> beginAttachment(
    List<Trail> sources, {
    List<Trail> targets = const [],
  }) => run(() => _beginAttachment(sources, targets, report: true));

  /// [targets] the walker chose are kept; [suggested] ones only when some
  /// points lie within their reach.
  Future<void> _beginAttachment(
    List<Trail> sources,
    List<Trail> targets, {
    List<Trail> suggested = const [],
    bool report = false,
  }) async {
    if (collaborative == null || sources.isEmpty) return;
    final points = [for (final s in sources) ...s.pois.map((p) => p.point)];
    final candidates = await _attachTargets(points);
    if (_disposed) return;
    final reachable = {for (final c in candidates) c.trail.sharedId};
    var chosen = targets.isNotEmpty
        ? targets
        : [
            for (final t in suggested)
              if (reachable.contains(t.sharedId)) t,
          ];
    if (chosen.isEmpty) {
      final best = candidates.firstOrNull;
      if (best == null) {
        if (report) message = AppMessage.noTrailNearPoints;
        return;
      }
      chosen = [await _fullTrail(best)];
    }
    attachTargets = candidates;
    await _planAttachment(sources, chosen);
  }

  /// Library trails, then catalogue trails around [points], ranked by how
  /// many points lie within reach; trails out of reach are left out.
  Future<List<AttachTarget>> _attachTargets(List<GeoPoint> points) async {
    final library = [
      for (final t in trails)
        if (t.followable && t.walk == null) t,
    ];
    final known = {
      for (final t in library) ...[t.id, t.sharedId],
    };
    final shared = <Trail>[];
    try {
      final area = await collaborative!.area(_around(points));
      shared.addAll([
        for (final s in area.trails)
          if (!known.contains(s.id)) s.preview,
      ]);
    } catch (_) {
      // Offline: the library's trails remain.
    }
    final ranked = await Isolate.run<List<AttachTarget>>(
      () => [
        for (final t in library) AttachTarget(t, pointsInRange(points, t)),
        for (final t in shared)
          AttachTarget(t, pointsInRange(points, t), catalogue: true),
      ],
    );
    return ranked.where((t) => t.inRange > 0).toList()
      ..sort((a, b) => b.inRange.compareTo(a.inRange));
  }

  /// The area within reach of [points].
  static Bounds _around(List<GeoPoint> points) {
    final margin = maximumImportedPlaceDistance / 110574;
    final south = points.map((p) => p.lat).reduce(math.min) - margin;
    final north = points.map((p) => p.lat).reduce(math.max) + margin;
    final lonMargin =
        margin /
        math.max(
          .01,
          math.cos(math.max(south.abs(), north.abs()) * math.pi / 180),
        );
    return Bounds(
      points.map((p) => p.lon).reduce(math.min) - lonMargin,
      south,
      points.map((p) => p.lon).reduce(math.max) + lonMargin,
      north,
    );
  }

  /// A catalogue trail is downloaded: points attach to its whole line.
  Future<Trail> _fullTrail(AttachTarget target) async {
    if (!target.catalogue) return target.trail;
    if (_browsed[target.trail.id] case final full?) return full;
    final full = await collaborative!.open(target.trail.id);
    _browsed[full.trail.id] = full.trail;
    _details[full.trail.sharedId] = full.details;
    return full.trail;
  }

  Future<void> _planAttachment(List<Trail> sources, List<Trail> targets) async {
    final known = places;
    final plan = await Isolate.run(
      () => PointAttachment.plan(sources, targets, known),
    );
    if (_disposed) return;
    attaching = plan;
    focus(targets.first);
  }

  /// Attach the points being previewed to [target] instead.
  Future<void> chooseAttachTarget(AttachTarget target) => run(() async {
    final sources = attaching?.sources;
    if (sources == null) return;
    await _planAttachment(sources, [await _fullTrail(target)]);
  });

  void cancelAttachment() {
    attaching = null;
    attachTargets = const [];
    notifyListeners();
  }

  /// Share the previewed points as places of their trail, offline included.
  /// The points left out stay in their file.
  Future<void> confirmAttachment() => run(() async {
    final plan = attaching;
    if (plan == null || collaborative == null) return;
    lastAttachment = await collaborative!.attachPoints(plan);
    attaching = null;
    attachTargets = const [];
    await reload();
    message = AppMessage.pointsAttached(
      plan.count(PointFate.added),
      plan.count(PointFate.known),
      plan.count(PointFate.tooFar) + plan.count(PointFate.unnamed),
    );
    _scheduleSync();
  });

  /// Withdraw the places the last attachment shared and restore its files.
  Future<void> undoAttachment() => run(() async {
    final last = lastAttachment;
    if (last == null || collaborative == null) return;
    await collaborative!.detachPoints(last);
    lastAttachment = null;
    await reload();
    message = AppMessage.attachmentUndone;
    _scheduleSync();
  });

  /// Reviews of the focused trail, as last read.
  TrailReviews? reviews;
  bool reviewsLoading = false;
  Object? reviewsError;
  String? _reviewsFor;
  Future<void> refreshReviews() async {
    final trail = focused;
    final id = trail == null || trail.walk != null || isPreview(trail)
        ? null
        : trail.sharedId;
    _reviewsFor = id;
    if (reviews?.trailId != id) reviews = null;
    reviewsError = null;
    if (id == null || collaborative == null) {
      reviewsLoading = false;
      notifyListeners();
      return;
    }
    reviewsLoading = true;
    notifyListeners();
    try {
      final result = await collaborative!.reviews(id);
      if (_reviewsFor == id) reviews = result;
    } catch (e) {
      if (_reviewsFor == id) reviewsError = e;
    } finally {
      if (_reviewsFor == id) {
        reviewsLoading = false;
        notifyListeners();
      }
    }
  }

  /// Walks recorded offline are pushed first: the API only accepts a review
  /// once the synced walks together covered the whole trail.
  Future<void> saveReview(int rating, String comment) =>
      _review((id) => collaborative!.review(id, rating, comment));
  Future<void> deleteReview() =>
      _review((id) => collaborative!.removeReview(id), deleted: true);
  Future<void> _review(
    Future<TrailReviews> Function(String) change, {
    bool deleted = false,
  }) => run(() async {
    final id = _reviewsFor;
    if (id == null || collaborative == null) return;
    try {
      syncStatus = await sync.synchronize();
    } catch (_) {
      // Offline: the review request reports it.
    }
    final result = await change(id);
    if (_reviewsFor == id) reviews = result;
    message = deleted ? AppMessage.reviewDeleted : AppMessage.reviewSaved;
  });
  final AnnounceProgress? recap;
  final TrailStatisticsStore? statistics;
  final Future<void> Function(Set<RecapItem>)? saveSpokenRecap;
  Set<RecapItem> get spokenRecap => recap?.spoken ?? const {};
  Future<void> setSpokenRecap(RecapItem item, bool spoken) async {
    if (recap == null) return;
    recap!.spoken = {...recap!.spoken}..remove(item);
    if (spoken) recap!.spoken.add(item);
    notifyListeners();
    try {
      await saveSpokenRecap?.call(recap!.spoken);
    } catch (_) {
      message = AppMessage.voiceGuidanceNotSaved;
      notifyListeners();
    }
  }

  void _summarize() {
    final recording = recorder?.current;
    if (recap == null || recording == null || !recording.active) return;
    final s = session;
    unawaited(
      recap!.update(
        recording,
        now: DateTime.now(),
        voice: voiceGuidance,
        foreground: foreground,
        session: approach == null && s != null && s.active ? s : null,
      ),
    );
  }

  final PlaceSearch? placeSearch;

  /// Last searched place the map should move to.
  Place? placeTarget;
  int placeRevision = 0;
  Future<List<Place>> searchPlaces(String query) async =>
      await placeSearch?.search(query, near: currentFix?.point) ?? const [];
  void showPlace(Place place) {
    placeTarget = place;
    placeRevision++;
    notifyListeners();
  }

  final GuideNavigation? guide;
  final Future<void> Function(bool)? saveVoiceGuidance;
  bool get voiceGuidance => guide?.voice ?? false;
  Future<void> setVoiceGuidance(bool enabled) async {
    if (guide == null) return;
    guide!.voice = enabled;
    notifyListeners();
    try {
      await saveVoiceGuidance?.call(enabled);
    } catch (_) {
      message = AppMessage.voiceGuidanceNotSaved;
      notifyListeners();
    }
  }

  /// Next direction change of the active session, for the visible map.
  UpcomingManeuver? get upcomingManeuver {
    final s = session;
    if (guide == null || s == null || !s.active || s.offTrail) return null;
    return guide!.upcoming(s, approach: approach != null);
  }

  void _track(Fix fix) {
    final s = session;
    if (s == null || !s.active) return;
    final now = DateTime.now();
    final left = s.accept(fix, now);
    if (left) unawaited(vibrate());
    if (guide != null) {
      unawaited(
        guide!.update(
          s,
          approach: approach != null,
          leftTrail: left,
          foreground: foreground,
          now: now,
        ),
      );
    }
  }

  final ApproachSource? approachSource;
  ApproachRoute? approach;
  bool approachReverse = false;
  GeoPoint? approachDestination;
  bool get atConnection =>
      approach != null &&
      session != null &&
      approachDestination != null &&
      approach!.arrived(session!, approachDestination!, DateTime.now());

  /// The walker reached the end of the trail followed while recording.
  bool get atTrailEnd {
    final s = session;
    return approach == null &&
        s != null &&
        recorder?.active == true &&
        trailEndReached(s, DateTime.now());
  }

  /// The stage to propose once the followed stage is walked: the neighbour
  /// with an end where the walker stands.
  NextStage? get nextStage {
    final point = session?.fix?.point;
    return point == null ? null : stagesOf(selected)?.following(point);
  }

  /// Finish the walk of a stage, then start [next] from where it ends. Each
  /// stage is its own walk, with its statistics.
  Future<void> finishStage([NextStage? next]) async {
    await finishWalk();
    if (next == null || _disposed || recorder?.current != null) return;
    showHistory = false;
    final trail = await _openStage(next.member);
    if (trail != null) await launch(trail, reverse: next.reverse);
  }

  Future<Trail?> _openStage(TrailGroupMember member) async {
    await openStage(member);
    final id = member.trail!.id;
    final trail = focused;
    return trail != null && (trail.sharedId == id || trail.id == id)
        ? trail
        : null;
  }

  /// Walk on along [route] after stopping, the next morning for instance:
  /// from where the walker stands, in the direction [reversed] of the last
  /// walk, or along the next stage once this one is behind them.
  Future<void> continueRoute(Trail route, {required bool reversed}) async {
    if (busy || _disposed || recorder?.current != null) return;
    Fix? fix;
    await run(() async {
      fix = await _positionForApproach();
      if (!_disposed) mapFix = fix;
    });
    final here = fix;
    if (here == null || _disposed) return;
    final plan = Continuation.of(
      route,
      here.point,
      reversed: reversed,
      links: await _loadStages(route),
    );
    showHistory = false;
    var target = route;
    if (plan.stage case final stage?) {
      final trail = await _openStage(stage.member);
      if (trail == null) return;
      target = trail;
    }
    await launch(target, reverse: plan.reverse);
  }

  Future<void> joinTrail(Trail target, {bool? reverse}) async {
    if (busy || approachSource == null) return;
    var ready = false;
    await run(() async {
      final backwards =
          reverse ??
          (selected?.id == target.id &&
              (approach != null ? approachReverse : session?.reverse == true));
      final fix = await _positionForApproach();
      if (_disposed) return;
      final end = nearestConnection(target, fix.point);
      if (end == null) {
        throw MessageFailure(AppMessage.noJoinSegment);
      }
      mapFix = fix;
      if (distance(fix.point, end) <= 25 && fix.accuracy <= 25) {
        select(target);
        session?.reverse = backwards;
        message = AppMessage.alreadyNearTrail;
        ready = true;
        return;
      }
      final route = await approachSource!.calculate(fix.point, target, end);
      if (_disposed) return;
      select(target);
      approach = route;
      approachDestination = end;
      approachReverse = backwards;
      session = TrackingSession(TrailGeometry(route.trail));
      if (route.cached) {
        message = AppMessage.cachedApproach;
      }
      unawaited(prepareTrailMaps([route.trail]));
      ready = true;
    });
    if (ready && !_disposed) await _startKeepingNotice();
  }

  /// Start a trail from wherever the walker is: follow it directly when
  /// already on it, otherwise walk the internal approach to its nearest point.
  /// [reverse] walks it backwards; by default the chosen direction is kept.
  Future<void> launch(Trail trail, {bool? reverse}) async {
    if (busy || !trail.followable || _disposed) return;
    // A catalogue trail being walked stays on the phone, maps included, so
    // guidance survives a lost connection or the app being closed.
    if (!stored(trail) && collaborative != null) {
      try {
        await _keepOffline(trail);
      } catch (e) {
        message = e;
        notifyListeners();
        return;
      }
      final id = trail.id;
      trail = trails.firstWhere((t) => t.id == id, orElse: () => trail);
    }
    final backwards =
        reverse ??
        (selected?.id == trail.id &&
            (approach != null ? approachReverse : session?.reverse == true));
    if (selected?.id != trail.id || session?.active == true) select(trail);
    unawaited(_loadStages(trail));
    if (approachSource != null) {
      await joinTrail(trail, reverse: backwards);
      if (_disposed ||
          session?.active == true ||
          selected?.id != trail.id ||
          approach != null) {
        return;
      }
    }
    // Offline without a saved approach, or no fix yet: follow the trail
    // itself; the remaining distance to it stays visible.
    if (message case MessageFailure(
      detail: AppMessage(code: 'approachUnavailable'),
    )) {
      message = AppMessage.approachFallback;
    }
    session?.reverse = backwards;
    await _startKeepingNotice();
  }

  Future<void> _startKeepingNotice() async {
    final notice = message;
    await start();
    if (message == null && notice != null) {
      message = notice;
      notifyListeners();
    }
  }

  /// Leave the itinerary view. An active walk keeps its trail on screen.
  void closeTrail() {
    if (planning) finishPlanning();
    if (session?.active == true) {
      focused = selected;
    } else {
      focused = null;
      selected = null;
      session = null;
      approach = null;
      approachDestination = null;
    }
    notifyListeners();
  }

  Future<Fix> _positionForApproach() async {
    await gps.requestAccess();
    if (currentFix?.reliable(DateTime.now()) == true) return currentFix!;
    return gps
        .watch()
        .where((f) => f.reliable(DateTime.now()))
        .timeout(
          const Duration(seconds: 20),
          onTimeout: (sink) {
            sink.addError(MessageFailure(AppMessage.gpsUnavailable));
            sink.close();
          },
        )
        .first;
  }

  Future<GeoPoint?> closestJoinPoint(Trail target) async {
    GeoPoint? result;
    await run(() async {
      final fix = await _positionForApproach();
      if (_disposed) return;
      mapFix = fix;
      result = nearestConnection(target, fix.point);
    });
    return result;
  }

  void cancelApproach() {
    final target = selected;
    final backwards = approachReverse;
    if (target == null) return;
    select(target);
    session?.reverse = backwards;
    notifyListeners();
  }

  Future<void> startOriginalTrail() async {
    cancelApproach();
    await start();
  }

  final HealthDataSource? health;
  Future<void> importHealth(Trail walk) => run(() async {
    if (health == null || walk.walk == null) return;
    final summary = await health!.read(
      walk.walk!.started,
      walk.walk!.ended ?? DateTime.now(),
    );
    if (summary.sources.isEmpty) {
      message = AppMessage.noWatchData;
      return;
    }
    if (recorder?.current?.saved.id == walk.id) {
      recorder!.current!.health = summary;
      await recorder!.save();
    } else {
      await library.repository.save(
        walk.withWalk(walk.walk!.withHealth(summary)),
      );
      await reload();
      _scheduleSync();
    }
    message = AppMessage.watchDataAdded;
  });
  final RecordWalk? recorder;
  StreamSubscription<void>? _recordChanges;
  StreamSubscription<Fix>? _recordFixes;
  List<Trail> history = [];
  bool showHistory = false;
  void viewHistory({Trail? walk}) {
    showHistory = true;
    focused = walk;
    focusRevision++;
    notifyListeners();
  }

  Future<void> _record({Trail? source}) async {
    if (recorder == null || recorder!.active) return;
    await _mapPositions?.cancel();
    _mapPositions = null;
    await _positions?.cancel();
    _positions = null;
    // A weight entered meanwhile in another health app applies to this walk.
    if (walker.weightKg == null) unawaited(refreshHealthWeight());
    await recorder!.start(source: source);
  }

  Future<void> freeWalk() => run(() async {
    await _record();
    notifyListeners();
  });
  Future<void> pauseWalk() => run(() async {
    stop();
    unawaited(recap?.leave());
    await recorder?.pause();
    if (_browsing && foreground) unawaited(browseLocation());
  });

  /// [name] and [description] are what the walker wrote when finishing;
  /// without them the walk keeps its provisional name.
  Future<void> finishWalk({
    String? name,
    String description = '',
  }) => run(() async {
    stop();
    unawaited(recap?.leave());
    final route = await recorder?.keepRoute(
      trails,
      name: name,
      description: description,
    );
    final walk = await recorder?.finish(routeId: route?.trail?.id, name: name);
    if (walk != null) {
      try {
        await statistics?.addWalk(walk);
      } catch (_) {
        // The server totals include the walk after its next sync.
      }
    }
    await reload();
    syncStatus = AppMessage.walkSavedPending;
    switch (route) {
      case WalkedRoute(outcome: WalkedRouteOutcome.created, :final trail?):
        showHistory = false;
        focus(trails.firstWhere((t) => t.id == trail.id, orElse: () => trail));
        message = AppMessage.routeCreated(trail.name);
        unawaited(prepareTrailMaps([trail]));
      case WalkedRoute(outcome: WalkedRouteOutcome.alreadyKnown, :final trail?):
        if (walk != null) viewHistory(walk: walk);
        message = AppMessage.routeAlreadyKnown(trail.name);
      case WalkedRoute(outcome: WalkedRouteOutcome.tooShort):
        if (walk != null) viewHistory(walk: walk);
        message = AppMessage.routeTooShort;
      default:
        if (walk != null) viewHistory(walk: walk);
    }
    if (walk != null && shareWithHealth) {
      try {
        await _share(walk, ask: false);
      } catch (_) {
        // The walk is saved; say what needs doing: send it again from history.
        message = AppMessage.healthShareFailed;
      }
    }
    _scheduleSync();
    if (_browsing && foreground) unawaited(browseLocation());
  });
  Trail? focused;
  int focusRevision = 0;
  bool planning = false, pickingStart = true;
  int? editingDay;
  double? draftStart, draftEnd;
  List<WalkingDay> get days => focused?.days ?? const [];
  bool get draftValid =>
      focused != null &&
      draftStart != null &&
      draftEnd != null &&
      WalkingDay(draftStart!, draftEnd!).valid(TrailGeometry(focused!).total);

  /// Browsing another route must not interrupt an active walking session.
  void focus(Trail trail) {
    if (planning) finishPlanning();
    focused = trail;
    focusRevision++;
    if (session?.active != true) select(trail);
    notifyListeners();
    unawaited(refreshReviews());
    unawaited(refreshDetails());
  }

  void beginPlanning(Trail trail) {
    focus(trail);
    planning = true;
    nextDay();
  }

  void nextDay() {
    editingDay = null;
    draftStart = days.lastOrNull?.end;
    draftEnd = null;
    pickingStart = draftStart == null;
    notifyListeners();
  }

  void editDay(int index) {
    editingDay = index;
    draftStart = days[index].start;
    draftEnd = days[index].end;
    pickingStart = true;
    notifyListeners();
  }

  void pickBoundary(bool start) {
    pickingStart = start;
    notifyListeners();
  }

  void placeBoundary(double along) {
    if (!planning || busy) return;
    if (pickingStart) {
      draftStart = along;
      pickingStart = false;
    } else {
      draftEnd = along;
    }
    notifyListeners();
  }

  Future<void> saveDay() => run(() async {
    if (!draftValid) return;
    final trail = focused!;
    final updated = [...days];
    final day = WalkingDay(draftStart!, draftEnd!);
    if (editingDay case final int index) {
      updated[index] = day;
    } else {
      updated.add(day);
    }
    final changed = trail.withDays(updated);
    await library.repository.save(changed);
    syncStatus = AppMessage.changesSavedPending;
    focused = changed;
    trails = [
      for (final t in trails)
        if (t.id == changed.id) changed else t,
    ];
    _scheduleSync();
    nextDay();
  });
  Future<void> deleteDay(int index) => run(() async {
    if (focused == null) return;
    final trail = focused!;
    final updated = [...days]..removeAt(index);
    final changed = trail.withDays(updated);
    await library.repository.save(changed);
    syncStatus = AppMessage.changesSavedPending;
    focused = changed;
    trails = [
      for (final t in trails)
        if (t.id == changed.id) changed else t,
    ];
    _scheduleSync();
    nextDay();
  });
  void finishPlanning() {
    planning = false;
    editingDay = null;
    draftStart = draftEnd = null;
    notifyListeners();
  }

  final PrepareMaps? automaticMaps;
  StreamSubscription<void>? _mapChanges;
  StreamSubscription<Fix>? _mapPositions;
  Fix? mapFix;
  bool _browsing = false;
  Fix? get currentFix => mapFix ?? session?.fix;
  Object get mapStatus => automaticMaps?.status ?? AppMessage.localMaps;
  Future<void> browseLocation() async {
    _browsing = true;
    if (_mapPositions != null ||
        !foreground ||
        _disposed ||
        recorder?.active == true) {
      return;
    }
    try {
      await gps.requestAccess();
      if (!_browsing || !foreground || _disposed || recorder?.active == true) {
        return;
      }
      _mapPositions = gps.watch().listen(
        (fix) {
          if (_disposed || !foreground) return;
          mapFix = fix;
          notifyListeners();
        },
        onError: (Object e) {
          message = e;
          notifyListeners();
        },
      );
    } catch (e) {
      message = e;
      notifyListeners();
    }
  }

  void stopBrowsing() {
    _browsing = false;
    unawaited(_mapPositions?.cancel());
    _mapPositions = null;
  }

  Future<void> prepareTrailMaps(List<Trail> items) async {
    try {
      await automaticMaps?.trails(items);
    } catch (_) {
      if (!_disposed) {
        message = AppMessage.mapsStorageUnavailable;
        notifyListeners();
      }
    }
  }

  final Library library;
  final MapRepository maps;
  final PositionSource gps;
  final Synchronizer sync;
  final Future<void> Function(bool) setAwake;
  final Future<void> Function() vibrate;
  final ConnectionDetails Function()? connectionDetails;
  final Future<void> Function()? loadDemo;
  Future<void> demonstrate() => run(() async {
    await loadDemo?.call();
    await refreshMaps();
    await reload();
    message = AppMessage.demoNotice;
  });
  final changes = StreamController<void>.broadcast();
  bool _disposed = false;
  void notifyListeners() {
    if (!changes.isClosed) changes.add(null);
  }

  List<Trail> trails = [];
  List<LocalMap> localMaps = [];
  String? mapStyle;
  int mapVersion = 0;
  List<Region> regions = [];
  Trail? selected;
  TrackingSession? session;
  StreamSubscription<Fix>? _positions;
  Timer? _retry;
  Timer? _freshness;
  bool busy = false, foreground = true, _resume = false;
  Object? message;
  double? progress;
  int _retrySeconds = 1;
  Object syncStatus = AppMessage.syncPending;
  Future<void> refreshMaps() async {
    localMaps = await maps.installed();
    mapStyle = automaticMaps?.style ?? await maps.composeStyle(localMaps);
    mapVersion++;
  }

  Future<void> initialize() async {
    await _loadProfile();
    unawaited(refreshHealthWeight());
    await recorder?.initialize();
    _recordChanges = recorder?.changes.stream.listen((_) => notifyListeners());
    _recordFixes = recorder?.fixes.stream.listen((fix) {
      if (_disposed) return;
      mapFix = fix;
      _track(fix);
      _summarize();
      notifyListeners();
    });
    await refreshMaps();
    await reload();
    if (automaticMaps != null) {
      _mapChanges = automaticMaps!.changes.stream.listen(
        (_) => notifyListeners(),
      );
      // The map opens at once; the saved download queue restores behind it.
      unawaited(_restoreMaps());
    }
    _scheduleSync();
  }

  Future<void> _restoreMaps() async {
    try {
      await automaticMaps!.initialize();
    } catch (_) {
      if (!_disposed) {
        message = AppMessage.mapsStorageUnavailable;
        notifyListeners();
      }
    }
    if (!_disposed) await prepareTrailMaps(trails);
  }

  Future<void> reload() async {
    if (_disposed) return;
    final all = await library.repository.all();
    await _loadProfile();
    trails = all.where((t) => t.walk == null).toList();
    history = all.where((t) => t.walk != null).toList()
      ..sort((a, b) => b.walk!.started.compareTo(a.walk!.started));
    places = await collaborative?.places() ?? const [];
    offlineCopies = await library.repository.offlineCopies();
    if (_disposed) return;
    _storedIds = {for (final t in trails) t.id};
    _pin();
    if (focused != null) {
      final id = focused!.id;
      focused = all.where((t) => t.id == id).firstOrNull ?? _browsed[id];
    }
    if (focused == null && planning) finishPlanning();
    if (selected != null && session?.active != true && approach == null) {
      final id = selected!.id;
      selected = trails.where((t) => t.id == id).firstOrNull ?? _browsed[id];
      final reverse = session?.reverse ?? false;
      session = selected?.followable == true
          ? TrackingSession(TrailGeometry(selected!))
          : null;
      session?.reverse = reverse;
    }
    notifyListeners();
  }

  Future<void>? _running, _background;
  Future<void> run(Future<void> Function() action) {
    if (busy || _disposed) return Future.value();
    final work = _run(action);
    _running = work;
    return work;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      message = e;
    } finally {
      busy = false;
      progress = null;
      notifyListeners();
      if (_resume && foreground && session?.active != true) unawaited(start());
    }
  }

  Future<void> import(String xml, String filename) =>
      importFiles([(xml, filename)]);

  /// Import GPX files chosen together. When they bring points files,
  /// attaching them is proposed at once: to [attachTo] when given, else to
  /// the tracks imported with them, else to the trail with most points within
  /// reach. A file that fails does not stop the others.
  Future<void> importFiles(List<(String, String)> files, {Trail? attachTo}) =>
      run(() async {
        final added = <Trail>[];
        var reused = 0;
        Object? failure;
        for (final (xml, filename) in files) {
          try {
            final imported = await library.import(xml, filename);
            added.addAll(imported.trails);
            reused += imported.reused;
          } catch (e) {
            failure ??= e;
          }
        }
        if (added.isEmpty) {
          if (failure != null) throw failure;
          return;
        }
        await reload();
        focus(added.first);
        unawaited(prepareTrailMaps(added));
        message =
            failure ??
            (reused == added.length
                ? AppMessage.trailsAlreadyShared(added.length)
                : AppMessage.itemsSaved(added.length));
        _scheduleSync();
        final sources = [
          for (final t in added)
            if (!t.followable && t.pois.isNotEmpty) t,
        ];
        await _beginAttachment(
          sources,
          [?attachTo],
          suggested: [
            for (final t in added)
              if (t.followable) t,
          ],
        );
      });
  void select(Trail trail) {
    stop();
    approach = null;
    approachDestination = null;
    focused = trail;
    selected = trail;
    session = trail.followable ? TrackingSession(TrailGeometry(trail)) : null;
    notifyListeners();
  }

  List<Poi> get pois => [
    ..._shownTrails.expand((t) => t.pois),
    for (final p in visiblePlaces) p.poi,
  ];
  Coverage get coverage => Coverage(localMaps.map((m) => m.region.bounds));
  bool covers(Trail trail) =>
      automaticMaps?.covers(trail) == true || coverage.covers(trail);
  bool regionCovers(Region r, Trail t) => Coverage([r.bounds]).covers(t);
  List<Trail> affectedByRemoval(LocalMap map) {
    final remaining = Coverage(
      localMaps
          .where((m) => m.region.id != map.region.id)
          .map((m) => m.region.bounds),
    );
    return trails.where((t) => covers(t) && !remaining.covers(t)).toList();
  }

  bool get covered => selected != null && covers(selected!);
  List<Region> get neededRegions => regions
      .where(
        (r) =>
            trails.any((t) => Coverage([r.bounds]).intersects(t)) &&
            !localMaps.any(
              (m) => m.region.id == r.id && m.region.sha256 == r.sha256,
            ),
      )
      .toList();
  int get neededBytes => neededRegions.fold(0, (v, r) => v + r.bytes);
  Future<void> prepareAll() async {
    for (final r in neededRegions.toList()) {
      await download(r);
      if (message != AppMessage.mapSaved) break;
    }
  }

  Future<void> removeTrail(Trail trail) => run(() async {
    if (selected?.id == trail.id) {
      stop();
      selected = null;
      session = null;
    }
    await library.repository.delete(trail.id);
    await reload();
  });

  /// Delete every finished walk of [walks] with a single refresh. The route
  /// they followed stays, and a walk still recording is kept.
  Future<void> removeWalks(Iterable<Trail> walks) => run(() async {
    for (final walk in walks) {
      if (walk.walk?.ended == null) continue;
      await library.repository.delete(walk.id);
    }
    await reload();
  });
  Future<void> start() async {
    if (session == null || busy) return;
    _resume = false;
    await run(() async {
      await gps.requestAccess();
      if (!foreground || _disposed) return;
      await guide?.prepare();
      if (!foreground || _disposed) return;
      if (recorder != null) await _record(source: selected);
      await _positions?.cancel();
      session!.resume();
      _freshness?.cancel();
      _freshness = Timer.periodic(
        const Duration(seconds: 5),
        (_) => notifyListeners(),
      );
      await setAwake(true);
      if (_disposed || !foreground) {
        await setAwake(false);
        return;
      }
      if (recorder == null) {
        _positions = gps.watch().listen(
          (fix) {
            if (!foreground || _disposed) return;
            _track(fix);
            notifyListeners();
          },
          onError: (Object e) {
            message = e;
            stop();
          },
        );
      }
    });
  }

  void stop() {
    _freshness?.cancel();
    _resume = false;
    session?.pause();
    unawaited(guide?.leave());
    unawaited(_positions?.cancel());
    _positions = null;
    unawaited(setAwake(false));
    notifyListeners();
  }

  void lifecycle(bool visible) {
    foreground = visible;
    if (recorder?.active == true) {
      unawaited(setAwake(visible && session?.active == true));
      if (visible) {
        automaticMaps?.retry();
        _scheduleSync();
      } else {
        _retry?.cancel();
      }
      return;
    }
    if (!visible) {
      unawaited(_mapPositions?.cancel());
      _mapPositions = null;
      final resume = _resume || (session?.active ?? false);
      stop();
      _resume = resume;
      _retry?.cancel();
    } else {
      if (_browsing) unawaited(browseLocation());
      automaticMaps?.retry();
      if (_resume) {
        unawaited(start());
      }
      _scheduleSync();
    }
  }

  void invert() {
    session?.invert();
    notifyListeners();
  }

  void mute() {
    session?.muted = true;
    notifyListeners();
  }

  Future<void> fetchCatalog() => run(() async {
    regions = await maps.catalog();
  });
  Future<void> download(Region r) => run(() async {
    await maps.download(r, (v) {
      progress = v;
      notifyListeners();
    });
    await refreshMaps();
    await reload();
    message = AppMessage.mapSaved;
  });
  Future<void> removeMap(LocalMap m) => run(() async {
    await maps.remove(m.region.id);
    await refreshMaps();
    await reload();
  });
  Future<void> profile() => run(() async {
    if (selected == null) return;
    final id = selected!.id;
    await library.prepareProfile(selected!);
    await reload();
    select(trails.firstWhere((t) => t.id == id));
  });
  Future<void> synchronize() => run(() async {
    message = syncStatus = await sync.synchronize();
    await reload();
  });
  void _scheduleSync() {
    _retry?.cancel();
    if (!foreground || _disposed || _background != null) return;
    _retry = Timer(Duration(seconds: _retrySeconds), () {
      if (_disposed) return;
      final work = _synchronizeInBackground();
      _background = work;
      unawaited(
        work.whenComplete(() {
          if (identical(_background, work)) _background = null;
          _scheduleSync();
        }),
      );
    });
  }

  Future<void> _synchronizeInBackground() async {
    try {
      syncStatus = await sync.synchronize();
      if (_disposed) return;
      _retrySeconds = 30;
      await reload();
    } catch (_) {
      syncStatus = AppMessage.syncRetry;
      notifyListeners();
      _retrySeconds = (_retrySeconds * 2).clamp(30, 300);
    }
  }

  Future<void> shutdown() async {
    dispose();
    await recorder?.close();
    try {
      await _running;
    } catch (_) {}
    try {
      await _background;
    } catch (_) {}
    await automaticMaps?.close();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _freshness?.cancel();
    _retry?.cancel();
    _positions?.cancel();
    _mapPositions?.cancel();
    _mapChanges?.cancel();
    _recordChanges?.cancel();
    _recordFixes?.cancel();
    unawaited(guide?.leave());
    unawaited(recap?.leave());
    unawaited(setAwake(false));
    changes.close();
  }
}
