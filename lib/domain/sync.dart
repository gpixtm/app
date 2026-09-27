import 'models.dart';

class SyncOperation {
  const SyncOperation(
    this.id,
    this.operationId,
    this.revision,
    this.deleted,
    this.trail,
  );
  final String id, operationId;
  final int revision;
  final bool deleted;
  final Trail trail;
}

class SyncResult {
  const SyncResult(this.revision, this.conflict);
  final int revision;
  final bool conflict;
}

abstract interface class SyncStore {
  Future<int> conflictsCount();
  Future<SyncOperation?> next();
  Future<void> acknowledge(SyncOperation operation, int revision);
  Future<void> conflict(SyncOperation operation);
  Future<void> merge(List<SyncOperation> remote);
  Future<void> preserveConflicts(List<SyncOperation> remote);
}

abstract interface class SyncTransport {
  Future<SyncResult> push(SyncOperation operation);
  Future<List<SyncOperation>> pull();
}
