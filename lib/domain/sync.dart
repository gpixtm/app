import 'models.dart';

class SyncOperation {
  const SyncOperation(
    this.id,
    this.operationId,
    this.revision,
    this.deleted,
    this.trail, {
    this.publicId,
  });
  final String id, operationId;
  final int revision;
  final bool deleted;
  final Trail trail;

  /// Shared trail the server linked to this library entry, when pulled.
  final String? publicId;
}

class SyncResult {
  const SyncResult(this.revision, this.conflict, {this.publicId});
  final int revision;
  final bool conflict;

  /// Shared trail the API published or reused for a synced library trail.
  final String? publicId;
}

abstract interface class SyncStore {
  Future<int> conflictsCount();
  Future<SyncOperation?> next();
  Future<void> acknowledge(
    SyncOperation operation,
    int revision, {
    String? publicId,
  });
  Future<void> conflict(SyncOperation operation);
  Future<void> merge(List<SyncOperation> remote);
  Future<void> preserveConflicts(List<SyncOperation> remote);
}

abstract interface class SyncTransport {
  Future<SyncResult> push(SyncOperation operation);
  Future<List<SyncOperation>> pull();
}
