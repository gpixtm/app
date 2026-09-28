import '../domain/models.dart';
import '../domain/trail_geometry.dart';

/// Anchor of each trail with a visible portion. A pin stays where it is while
/// still on screen, so panning never makes it jump; only trails whose pin left
/// the view (or that just entered it) get a new one at their visible centre.
List<(Trail, GeoPoint)> stickyAnchors(
  List<(Trail, GeoPoint)> previous,
  List<Trail> trails,
  Bounds view,
) {
  final kept = {
    for (final (trail, point) in previous)
      if (view.contains(point)) trail.id: point,
  };
  return [
    for (final trail in trails)
      if (kept[trail.id] ?? TrailGeometry(trail).visibleCentre(view)
          case final point?)
        (trail, point),
  ];
}

/// Map sources of the pins: the walker's own trails and catalogue trails are
/// clustered separately, so a cluster never mixes colours.
const ownPinSource = 'own-pins';
const cataloguePinSource = 'catalogue-pins';

/// GeoJSON points of the anchors of one kind, identified by trail and
/// labelled with their length. The map clusters them itself: overlapping pins become one "N" bubble, split again
/// while zooming in, without any work on the Flutter side while moving.
Map<String, dynamic> pinFeatures(
  List<(Trail, GeoPoint)> anchors, {
  required bool catalogue,
  required bool Function(Trail) isCatalogue,
  String Function(Trail)? label,
}) => {
  'type': 'FeatureCollection',
  'features': [
    for (final (trail, point) in anchors)
      if (isCatalogue(trail) == catalogue)
        {
          'type': 'Feature',
          'id': trail.id,
          'properties': {'trail': trail.id, 'label': label?.call(trail) ?? ''},
          'geometry': {
            'type': 'Point',
            'coordinates': [point.lon, point.lat],
          },
        },
  ],
};

/// Trails of the anchors, nearest to [centre] first, as the list under the
/// map shows them.
List<Trail> nearestFirst(List<(Trail, GeoPoint)> anchors, GeoPoint centre) {
  final sorted = [...anchors]
    ..sort((a, b) => distance(a.$2, centre).compareTo(distance(b.$2, centre)));
  return [for (final (trail, _) in sorted) trail];
}
