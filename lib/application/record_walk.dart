import '../domain/app_message.dart';

import 'dart:async';
import 'dart:isolate';

import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/trail_identity.dart';
import '../domain/walk_recording.dart';
import '../domain/walked_route.dart';

class RecordWalk {
  RecordWalk(
    this.store,
    this.repository,
    this.gps,
    this.newId, {
    this.freeWalkName,
    this.routeName,
    this.identity,
  });
  final String Function()? freeWalkName;

  /// A route takes the shared identifier of its line when available.
  final TrailIdentity? identity;
  final String Function(DateTime started)? routeName;
  final String Function() newId;
  final RecordingStore store;
  final TrailRepository repository;
  final PositionSource gps;
  final changes = StreamController<void>.broadcast();
  final fixes = StreamController<Fix>.broadcast();
  WalkRecording? current;
  Object? error;
  StreamSubscription<Fix>? _positions;
  Timer? _checkpoint;
  Future<void> _writes = Future.value();
  bool _closed = false;
  bool get active => current?.active == true;
  void notify() {
    if (!_closed) changes.add(null);
  }

  Future<void> initialize() async {
    final saved = await store.read();
    if (saved != null) {
      // Finishing can be interrupted between the durable history write and clear.
      if ((await repository.all()).any(
        (t) => t.id == saved.id && t.walk?.ended != null,
      )) {
        await store.clear();
      } else {
        current = WalkRecording(saved);
      }
    }
  }

  Future<void> start({Trail? source}) async {
    if (_closed || active) return;
    await gps.requestAccess();
    if (_closed) return;
    final now = DateTime.now();
    current ??= WalkRecording(
      Trail(
        id: newId(),
        name: source?.name ?? freeWalkName?.call() ?? 'Walk',
        segments: [],
        pois: [],
        walk: WalkDetails(started: now, seconds: 0, sourceTrailId: source?.id),
      ),
    );
    current!.resume(now);
    error = null;
    await save();
    _positions = gps.watch().listen(
      (fix) {
        if (_closed || !active) return;
        if (current!.accept(fix, DateTime.now())) unawaited(save());
        fixes.add(fix);
        notify();
      },
      onError: (Object e) {
        error = AppMessage.recordingSuspended(e);
        unawaited(pause());
      },
    );
    _checkpoint = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(save());
      notify();
    });
    notify();
  }

  Future<void> save() {
    if (current == null) return _writes;
    final snapshot = current!.snapshot(DateTime.now());
    _writes = _writes.then((_) => store.write(snapshot)).catchError((Object e) {
      error = AppMessage.walkSaveFailed(e);
      notify();
    });
    return _writes;
  }

  Future<void> pause() async {
    current?.pause(DateTime.now());
    _checkpoint?.cancel();
    await _positions?.cancel();
    _positions = null;
    await save();
    notify();
  }

  /// Turn the current free walk into a reusable route, before [finish], so an
  /// interrupted finish retried later finds that route instead of duplicating
  /// it. Walks guided by a GPX never create a route.
  Future<WalkedRoute?> keepRoute(List<Trail> known) async {
    final recording = current;
    if (recording == null || recording.saved.walk!.sourceTrailId != null) {
      return null;
    }
    await pause();
    final walk = recording.snapshot(DateTime.now());
    // The route's line decides its shared identity, like an imported GPX.
    final fingerprint = identity?.fingerprint(walk.segments);
    final id = fingerprint == null ? newId() : identity!.sharedId(fingerprint);
    final name = routeName?.call(walk.walk!.started) ?? walk.name;
    final routes = known.where((t) => t.walk == null).toList();
    final result = await Isolate.run(
      () => routeFromWalk(walk, routes, id: id, name: name),
    );
    if (result.outcome == WalkedRouteOutcome.created) {
      await repository.save(result.trail!);
    }
    return result;
  }

  /// [routeId] links a free walk to the route it created or matched.
  Future<Trail?> finish({String? routeId}) async {
    if (current == null) return null;
    await pause();
    final result = current!.snapshot(
      DateTime.now(),
      finished: true,
      routeId: routeId,
    );
    await repository.save(result);
    await store.clear();
    current = null;
    error = null;
    notify();
    return result;
  }

  Future<void> close() async {
    _closed = true;
    await pause();
    await _writes;
    await changes.close();
    await fixes.close();
  }
}
