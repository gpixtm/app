import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/trail_geometry.dart';
import 'design.dart';
import 'localization.dart';

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

/// One or more trails whose visible portions overlap on screen. A pin holds
/// either the walker's own trails or catalogue trails, never both, so its
/// colour always says which.
class TrailPin {
  TrailPin(this.trails, this.position, {this.catalogue = false});
  final List<Trail> trails;
  final Offset position;
  final bool catalogue;
}

/// Greedy screen-space grouping: anchors closer than [radius] logical pixels
/// to a pin of the same kind join it, so overlapping trails become one
/// "N trails" pin.
List<TrailPin> clusterPins(
  List<(Trail, Offset)> anchors, {
  double radius = 44,
  bool Function(Trail)? catalogue,
}) {
  final groups = <(List<Trail>, List<Offset>, bool)>[];
  Offset centre(List<Offset> points) =>
      points.reduce((a, b) => a + b) / points.length.toDouble();
  for (final (trail, position) in anchors) {
    final kind = catalogue?.call(trail) ?? false;
    final group = groups
        .where(
          (g) => g.$3 == kind && (centre(g.$2) - position).distance < radius,
        )
        .firstOrNull;
    if (group == null) {
      groups.add(([trail], [position], kind));
    } else {
      group.$1.add(trail);
      group.$2.add(position);
    }
  }
  return [
    for (final (trails, points, kind) in groups)
      TrailPin(trails, centre(points), catalogue: kind),
  ];
}

class TrailPinView extends StatelessWidget {
  const TrailPinView(this.pin, {required this.onTap, super.key});
  final TrailPin pin;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final single = pin.trails.length == 1;
    return Semantics(
      button: true,
      label: [
        single
            ? context.l10n.showTrail(pin.trails.single.name)
            : context.l10n.trailCount(pin.trails.length),
        pin.catalogue
            ? context.l10n.catalogueTrailLabel
            : context.l10n.ownTrailLabel,
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 34,
          constraints: const BoxConstraints(minWidth: 34),
          padding: EdgeInsets.symmetric(horizontal: single ? 0 : 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pin.catalogue ? catalogueColor : forest,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: single
              ? Icon(
                  pin.catalogue ? Icons.travel_explore : Icons.hiking,
                  color: Colors.white,
                  size: 18,
                )
              : Text(
                  context.l10n.trailCount(pin.trails.length),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}
