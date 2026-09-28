import 'models.dart';

/// A searchable place (address, town, summit…) used to move the map.
class Place {
  const Place({
    required this.name,
    required this.point,
    this.detail = '',
    this.extent,
  });

  /// Provider place names are user-facing data and keep their original text.
  final String name, detail;
  final GeoPoint point;
  final Bounds? extent;
}

abstract interface class PlaceSearch {
  /// Requires the network; failures carry an `AppMessage`.
  Future<List<Place>> search(String query, {GeoPoint? near});
}
