import '../domain/app_message.dart';

import 'dart:async';
import 'dart:isolate';

import '../domain/automatic_maps.dart';
import '../domain/models.dart';

/// Durable preparation queue. Foreground view requests take priority over GPX
/// preparation; completed areas are never downloaded again.
class PrepareMaps {
  PrepareMaps(this.store);
  final AutomaticMapStore store;
  final changes = StreamController<void>.broadcast();
  final _areas = <String, MapArea>{};
  final _ready = <String>{};
  final _routes = <String, Set<String>>{};
  final List<String> _queue = [];
  Future<void> _writes = Future.value();
  bool _closed = false, _working = false;
  Timer? _retry;
  Object? error;
  double progress = 0;
  int get readyCount => _ready.length;
  int get pendingCount => _areas.length - _ready.length;
  String get style => store.style;
  Object get status =>
      error ??
      (pendingCount > 0
          ? AppMessage.mapProgress(
              readyCount,
              _areas.length,
              (progress * 100).round(),
            )
          : AppMessage.savedAreas(readyCount));
  bool covers(Trail trail) =>
      _routes[trail.id]?.isNotEmpty == true &&
      _routes[trail.id]!.every(_ready.contains);
  void _notify() {
    if (!_closed) changes.add(null);
  }

  Future<void> initialize() async {
    for (final saved in await store.restore()) {
      _areas[saved.area.key] = saved.area;
      if (saved.ready) {
        _ready.add(saved.area.key);
      } else {
        _queue.add(saved.area.key);
      }
    }
    _kick();
  }

  Future<void> trails(List<Trail> trails) async {
    final plans = await Isolate.run(
      () => {for (final t in trails) t.id: MapPlan.trail(t)},
    );
    if (_closed) return;
    for (final entry in plans.entries) {
      _routes[entry.key] = entry.value.map((a) => a.key).toSet();
      _add(entry.value, false);
    }
    await _persist();
    _notify();
    _kick();
  }

  Future<void> viewport(Bounds bounds, double zoom) async {
    if (_closed) return;
    if (!_add(MapPlan.viewport(bounds, zoom), true)) return;
    await _persist();
    _kick();
  }

  bool _add(List<MapArea> areas, bool priority) {
    var changed = false;
    for (final area in areas) {
      if (_areas.containsKey(area.key)) {
        if (priority && _queue.remove(area.key)) _queue.insert(0, area.key);
        continue;
      }
      changed = true;
      _areas[area.key] = area;
      if (priority) {
        _queue.insert(0, area.key);
      } else {
        _queue.add(area.key);
      }
    }
    return changed;
  }

  Future<void> _persist() {
    final snapshot = _areas.values.toList();
    final next = _writes.then((_) => store.remember(snapshot));
    _writes = next.catchError((Object _) {});
    return next;
  }

  void retry() {
    error = null;
    _retry?.cancel();
    _kick();
  }

  void _kick() {
    if (!_closed && !_working) unawaited(_run());
  }

  Future<void> _run() async {
    _working = true;
    try {
      while (!_closed && _queue.isNotEmpty) {
        final key = _queue.removeAt(0);
        progress = 0;
        try {
          await store.download(_areas[key]!, (value) {
            progress = value;
            _notify();
          });
          if (_closed) break;
          _ready.add(key);
          error = null;
        } catch (_) {
          if (_closed) break;
          _queue.add(key);
          error = AppMessage.mapPreparationPending;
          _retry?.cancel();
          _retry = Timer(const Duration(seconds: 30), retry);
          _notify();
          break;
        }
        _notify();
      }
    } finally {
      _working = false;
    }
  }

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    await _writes;
    await store.close();
    await changes.close();
  }
}
