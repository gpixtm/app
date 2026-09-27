import 'models.dart';

abstract interface class TrailRepository {
  Future<List<Trail>> all();
  Future<void> save(Trail trail);
  Future<void> delete(String id);
}

abstract interface class GpxDecoder {
  List<Trail> decode(String source, String name);
}

abstract interface class PositionSource {
  Stream<Fix> watch();
  Future<void> requestAccess();
}

abstract interface class ElevationSource {
  Future<Trail> complete(Trail trail);
}

abstract interface class Synchronizer {
  Future<Object> synchronize();
  Future<void> resolveConflicts();
}

class Region {
  const Region({
    required this.id,
    required this.name,
    required this.version,
    required this.bytes,
    required this.sha256,
    required this.url,
    required this.bounds,
  });
  final String id, name, version, sha256, url;
  final int bytes;
  final Bounds bounds;
}

class LocalMap {
  const LocalMap(this.region, this.stylePath);
  final Region region;
  final String stylePath;
}

abstract interface class MapRepository {
  Future<List<Region>> catalog();
  Future<List<LocalMap>> installed();
  Future<String?> composeStyle(List<LocalMap> maps);
  Future<void> download(Region region, void Function(double) progress);
  Future<void> remove(String id);
}
