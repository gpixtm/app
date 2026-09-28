import '../domain/app_message.dart';

import 'dart:async';

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
  });
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
    if (ready && !_disposed) await start();
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
    await recorder?.pause();
    if (_browsing && foreground) unawaited(browseLocation());
  });
  Future<void> finishWalk() => run(() async {
    stop();
    final walk = await recorder?.finish();
    await reload();
    if (walk != null) viewHistory(walk: walk);
    syncStatus = AppMessage.walkSavedPending;
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
    final added = await library.import(xml, filename);
    await reload();
    focus(added.first);
    unawaited(prepareTrailMaps(added));
    message = AppMessage.itemsSaved(added.length);
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

  List<Poi> get pois => trails.expand((t) => t.pois).toList();
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
    unawaited(setAwake(false));
    changes.close();
  }
}
