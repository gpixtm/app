import '../domain/app_message.dart';

import 'dart:async';

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
import '../domain/place_search.dart';
import '../domain/shared_trails.dart';
import '../domain/trail_statistics.dart';
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
  });

  /// Trails every walker shared; absent in tests and older setups.
  final CollaborativeTrails? collaborative;

  /// Offline catalogue of shared trails.
  List<SharedTrail> shared = [];
  Map<String, SharedTrail> _sharedById = {};

  /// Every trail marked by a pin: the library, then shared trails not in it.
  /// A shared trail appears as a light preview until opened.
  List<Trail> pinned = [];
  Set<String> _previews = {};
  bool isPreview(Trail trail) => _previews.contains(trail.id);
  SharedTrail? sharedFor(Trail trail) => _sharedById[trail.sharedId];

  /// Show a pinned trail: a shared preview is downloaded once, then kept.
  Future<void> open(Trail trail) async {
    if (!isPreview(trail) || collaborative == null) {
      focus(trail);
      return;
    }
    await run(() async {
      final full = await collaborative!.open(trail.id);
      await reload();
      if (_disposed) return;
      focus(trails.firstWhere((t) => t.id == full.id, orElse: () => full));
      unawaited(prepareTrailMaps([full]));
    });
  }

  /// Places walkers added on shared trails, this phone's pending ones included.
  List<TrailPlace> places = [];

  /// Places of the trails on this phone, shown with their GPX points.
  List<TrailPlace> get visiblePlaces {
    final ids = {
      for (final t in trails) ...[t.id, t.sharedId],
    };
    return [
      for (final p in places)
        if (ids.contains(p.trailId)) p,
    ];
  }

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
  /// once one synced walk covered the whole trail.
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
  Future<void> launch(Trail trail) async {
    if (busy || !trail.followable || _disposed) return;
    final backwards =
        selected?.id == trail.id &&
        (approach != null ? approachReverse : session?.reverse == true);
    if (selected?.id != trail.id || session?.active == true) select(trail);
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
  Future<void> finishWalk() => run(() async {
    stop();
    unawaited(recap?.leave());
    final route = await recorder?.keepRoute(trails);
    final walk = await recorder?.finish(routeId: route?.trail?.id);
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
      await automaticMaps!.initialize();
      unawaited(prepareTrailMaps(trails));
    }
    _scheduleSync();
  }

  Future<void> reload() async {
    if (_disposed) return;
    final all = await library.repository.all();
    trails = all.where((t) => t.walk == null).toList();
    history = all.where((t) => t.walk != null).toList()
      ..sort((a, b) => b.walk!.started.compareTo(a.walk!.started));
    shared = await collaborative?.catalogue() ?? const [];
    places = await collaborative?.places() ?? const [];
    if (_disposed) return;
    _sharedById = {for (final s in shared) s.id: s};
    final known = {
      for (final t in trails) ...[t.id, ?t.publicId],
    };
    final previews = [
      for (final s in shared)
        if (!known.contains(s.id)) s.preview,
    ];
    _previews = {for (final t in previews) t.id};
    pinned = [...trails, ...previews];
    if (focused != null) {
      focused = all.where((t) => t.id == focused!.id).firstOrNull;
    }
    if (focused == null && planning) finishPlanning();
    if (selected != null && session?.active != true && approach == null) {
      selected = trails.where((t) => t.id == selected!.id).firstOrNull;
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

  Future<void> import(String xml, String filename) => run(() async {
    final imported = await library.import(xml, filename);
    final added = imported.trails;
    await reload();
    focus(added.first);
    unawaited(prepareTrailMaps(added));
    message = imported.reused == added.length
        ? AppMessage.trailsAlreadyShared(added.length)
        : AppMessage.itemsSaved(added.length);
    _scheduleSync();
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
    ...trails.expand((t) => t.pois),
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
