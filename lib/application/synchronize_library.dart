import '../domain/app_message.dart';
import '../domain/ports.dart';
import '../domain/sync.dart';

class SynchronizeLibrary implements Synchronizer {
  SynchronizeLibrary(this.store, this.transport);
  final SyncStore store;
  final SyncTransport transport;
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
          await store.acknowledge(op, result.revision);
        }
      }
      await store.merge(await transport.pull());
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
