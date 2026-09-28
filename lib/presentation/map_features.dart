import '../domain/models.dart';

Map<String, dynamic> collection(Iterable<Map<String, dynamic>> features) => {
  'type': 'FeatureCollection',
  'features': features.toList(),
};
Map<String, dynamic> feature(
  String type,
  dynamic coordinates, [
  Map<String, dynamic> properties = const {},
]) => {
  'type': 'Feature',
  'properties': properties,
  'geometry': {'type': type, 'coordinates': coordinates},
};
Iterable<Map<String, dynamic>> lines(
  List<List<GeoPoint>> segments, {
  String color = '#39765c',
}) sync* {
  for (final segment in segments) {
    if (segment.length > 1) {
      yield feature(
        'LineString',
        [
          for (final p in segment) [p.lon, p.lat],
        ],
        {'color': color},
      );
    }
  }
}
