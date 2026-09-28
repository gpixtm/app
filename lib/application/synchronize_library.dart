import '../domain/app_message.dart';
import '../domain/ports.dart';
import '../domain/shared_trails.dart';
import '../domain/sync.dart';
import '../domain/trail_statistics.dart';

class SynchronizeLibrary implements Synchronizer {
  SynchronizeLibrary(
    this.store,
    this.transport, {
    this.statistics,
    this.shared,
  });
  final SyncStore store;
  final SyncTransport transport;

  /// Refreshes the running GPX statistics once every local walk was pushed.
  final ({StatisticsTransport transport, TrailStatisticsStore store})?
  statistics;
  Future<void> _refreshStatistics() async {
    final s = statistics;
    if (s == null) return;
    try {
      await s.store.replaceAll(await s.transport.fetch());
    } catch (_) {
      // An older API without statistics must not fail the library sync;
      // the cache and local increments stay in use.
    }
  }

  /// Places walkers add on shared trails. The catalogue itself is browsed
  /// on the server and never copied here.
  final ({SharedTrailTransport transport, SharedTrailStore store})? shared;

  /// Send this phone's place changes, then pull other walkers' places since
  /// the last stored cursor, page by page.
  Future<void> refreshShared() async {
    final s = shared;
    if (s == null) return;
    try {
      await _sendPlaces(s.transport, s.store);
      var since = await s.store.placeCursor();
      while (true) {
        final page = await s.transport.places(since);
        await s.store.applyPlaces(page);
        if (!page.more || page.next <= since) break;
        since = page.next;
      }
    } catch (_) {
      // Places added offline stay queued until the next sync.
    }
  }

  /// A place waits while its trail is not shared yet (404, for a trail added
  /// offline); a refusal (too far, invalid, not the author) drops it.
  Future<void> _sendPlaces(
    SharedTrailTransport transport,
    SharedTrailStore store,
  ) async {
    for (final pending in await store.pendingPlaces()) {
      try {
        final result = pending.delete
            ? await transport.removePlace(pending.place)
            : await transport.savePlace(pending.place);
        await store.placeSent(pending, result);
      } on RemoteFailure catch (e) {
        if (e.status == 404 && !pending.delete) continue;
        if (e.status == 403 || e.status == 404 || e.status == 422) {
          await store.placeSent(pending, null);
          continue;
        }
        rethrow;
      }
    }
  }

  bool _running = false;
  @override
  Future<Object> synchronize() async {
    if (_running) return AppMessage.syncRunning;
    _running = true;
    try {
      while (true) {
        final op = await store.next();
        if (op == null) break;
        final result = await transport.push(op);
        if (result.conflict) {
          await store.conflict(op);
        } else {
          await store.acknowledge(
            op,
            result.revision,
            publicId: result.publicId,
          );
        }
      }
      await store.merge(await transport.pull());
      await _refreshStatistics();
      await refreshShared();
      final conflicts = await store.conflictsCount();
      return conflicts == 0
          ? AppMessage.librarySynced
          : AppMessage.syncConflicts(conflicts);
    } finally {
      _running = false;
    }
  }

  @override
  Future<void> resolveConflicts() async {
    if (_running) throw MessageFailure(AppMessage.waitForSync);
    _running = true;
    try {
      await store.preserveConflicts(await transport.pull());
    } finally {
      _running = false;
    }
  }
}
