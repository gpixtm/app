import 'localization.dart';
import 'design.dart' show decimal, catalogueHex, ownTrailHex, shortKilometers;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../domain/models.dart';
import '../domain/place_search.dart';
import '../domain/heading.dart';
import '../domain/trail_geometry.dart';
import '../application/app_controller.dart';
import 'map_features.dart';
import 'position_arrow.dart';
import 'pin_images.dart';
import 'trail_pins.dart';
import 'trail_places.dart';

const dayColors = ['#c66a25', '#7956b2', '#087e8b', '#b03c68'];

/// The trail a walk followed, shown faintly beneath the walk in history.
const referenceHex = '#8fa89c';
const navigationZoom = 16.0;

class TrailMap extends StatefulWidget {
  const TrailMap(this.app, {this.onPin, this.onVisibleTrails, super.key});
  final AppController app;

  /// A pin was touched: one trail, or several sharing the pin.
  final void Function(List<Trail>)? onPin;

  /// The pinned trails now on screen, nearest to its centre first, each
  /// time the camera stops or the pinned trails change.
  final void Function(List<Trail>)? onVisibleTrails;
  @override
  State<TrailMap> createState() => _TrailMapState();
}

class _TrailMapState extends State<TrailMap> {
  MapLibreMapController? controller;
  StreamSubscription<CompassEvent>? compass;
  StreamSubscription<void>? changes;
  final pointer = HeadingFilter(seconds: .22, deadband: 1);
  final cameraHeading = HeadingFilter(seconds: .85, deadband: 3);
  bool loaded = false, follow = true, headingUp = true;
  bool updating = false, pending = false, wasActive = false;
  bool resetNavigationZoom = false;
  Object? followedSession;
  DateTime lastCamera = DateTime(2000), lastRender = DateTime(2000);
  DateTime? headingTime;
  int focusRevision = 0;
  late int placeRevision = app.placeRevision;
  Object? renderedTrails;
  String? renderedSelection;
  Object? renderedDays;
  Object? renderedHistory;
  Object? renderedApproach;
  Object? renderedApproachMarkers;
  bool? renderedShowHistory;
  int? renderedSamples;
  double? renderedStart, renderedEnd;
  bool? renderedPlanning;
  List<Map<String, dynamic>> markers = [];
  List<({math.Point point, String label, String color})> markerViews = [];

  /// Zoom the direction arrow was last sized for.
  double? arrowZoom;
  late final Future<Uint8List> ownPin = trailPinPng(
    MediaQuery.devicePixelRatioOf(context),
    catalogue: false,
  );
  late final Future<Uint8List> cataloguePin = trailPinPng(
    MediaQuery.devicePixelRatioOf(context),
    catalogue: true,
  );

  /// Centre of each unselected trail's visible portion. Trails are only drawn
  /// once selected; until then a pin is their only mark on the map. Pins are
  /// map layers clustered by the map itself, recomputed only when the camera
  /// stops or the pinned trails change, never while moving.
  List<(Trail, GeoPoint)> anchors = [];
  Object? anchoredTrails;
  bool? anchoredPins;
  String? anchoredFocus;
  bool get showPins => !app.planning && app.session?.active != true;
  bool projecting = false, projectAgain = false;
  Future<void> refreshAnchors() async {
    final c = controller;
    if (!loaded || c == null) return;
    anchoredTrails = app.pinned;
    anchoredPins = showPins;
    anchoredFocus = app.focused?.id;
    GeoPoint? centre;
    if (!showPins) {
      anchors = [];
    } else {
      final region = await c.getVisibleRegion();
      if (!mounted) return;
      final view = Bounds(
        region.southwest.longitude,
        region.southwest.latitude,
        region.northeast.longitude,
        region.northeast.latitude,
      );
      centre = GeoPoint(
        (view.south + view.north) / 2,
        (view.west + view.east) / 2,
      );
      anchors = stickyAnchors(anchors, [
        for (final trail in app.pinned)
          if (trail.id != app.focused?.id) trail,
      ], view);
    }
    for (final catalogue in [false, true]) {
      await c.setGeoJsonSource(
        catalogue ? cataloguePinSource : ownPinSource,
        pinFeatures(
          anchors,
          catalogue: catalogue,
          isCatalogue: (trail) => !app.stored(trail),
          label: (trail) => shortKilometers(
            app.sharedFor(trail)?.metres ?? TrailGeometry(trail).total,
          ),
        ),
      );
    }
    if (mounted) {
      widget.onVisibleTrails?.call(
        centre == null ? const [] : nearestFirst(anchors, centre),
      );
    }
  }

  static const pinLayers = [
    'own-pin-clusters',
    'own-pin-points',
    'catalogue-pin-clusters',
    'catalogue-pin-points',
  ];

  /// A touched pin opens its trail (or lists the trails sharing its spot); a
  /// touched cluster zooms in until it splits, as on AllTrails.
  Future<bool> tapPin(math.Point<double> screen) async {
    final c = controller;
    if (c == null || !showPins) return false;
    final ratio = defaultTargetPlatform == TargetPlatform.android
        ? MediaQuery.devicePixelRatioOf(context)
        : 1.0;
    final List hits;
    try {
      hits = await c.queryRenderedFeaturesInRect(
        Rect.fromCenter(
          center: Offset(screen.x, screen.y),
          width: 36 * ratio,
          height: 36 * ratio,
        ),
        pinLayers,
        null,
      );
    } catch (_) {
      return false;
    }
    if (!mounted || hits.isEmpty) return false;
    final features = [
      for (final hit in hits)
        if (hit is Map) hit.cast<String, dynamic>(),
    ];
    final ids = {
      for (final f in features)
        if ((f['properties'] as Map?)?['trail'] case final String id) id,
    };
    final trails = [
      for (final trail in app.pinned)
        if (ids.contains(trail.id)) trail,
    ];
    if (trails.isNotEmpty) {
      if (widget.onPin != null) {
        widget.onPin!(trails);
      } else {
        unawaited(app.open(trails.first));
      }
      return true;
    }
    final cluster = features
        .where((f) => (f['properties'] as Map?)?['cluster'] == true)
        .firstOrNull;
    final coordinates = (cluster?['geometry'] as Map?)?['coordinates'] as List?;
    if (coordinates == null) return false;
    follow = false;
    await c.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          (coordinates[1] as num).toDouble(),
          (coordinates[0] as num).toDouble(),
        ),
        (c.cameraPosition?.zoom ?? 10) + 2,
      ),
    );
    return true;
  }

  Future<void> projectMarkers() async {
    if (!loaded || !mounted) return;
    projectAgain = true;
    if (projecting) return;
    projecting = true;
    try {
      while (projectAgain && loaded && mounted) {
        projectAgain = false;
        final snapshot = markers;
        final locations = snapshot.isEmpty
            ? const <math.Point>[]
            : await controller!.toScreenLocationBatch([
                ...snapshot.map((m) {
                  final coordinates = m['geometry']['coordinates'] as List;
                  return LatLng(
                    coordinates[1] as double,
                    coordinates[0] as double,
                  );
                }),
              ]);
        if (!mounted) return;
        if (!identical(snapshot, markers)) {
          projectAgain = true;
          continue;
        }
        setState(() {
          markerViews = [
            for (var i = 0; i < snapshot.length; i++)
              (
                point: locations[i],
                label: snapshot[i]['properties']['label'] as String,
                color: snapshot[i]['properties']['color'] as String,
              ),
          ];
        });
      }
    } catch (_) {
      /* The map can be disposed during a projection. */
    } finally {
      projecting = false;
    }
  }

  AppController get app => widget.app;
  bool get navigating =>
      app.session?.active == true || app.recorder?.active == true;

  @override
  void initState() {
    super.initState();
    unawaited(app.browseLocation());
    changes = app.changes.stream.listen((_) => update());
    compass = FlutterCompass.events?.listen((e) {
      if (!app.foreground ||
          !navigating ||
          e.heading == null ||
          !e.heading!.isFinite) {
        return;
      }
      final now = DateTime.now();
      pointer.add(e.heading!, now);
      cameraHeading.add(pointer.value!, now);
      headingTime = now;
      if (now.difference(lastRender).inMilliseconds >= 100) {
        lastRender = now;
        unawaited(update());
      }
    });
  }

  @override
  void dispose() {
    loaded = false;
    app.stopBrowsing();
    changes?.cancel();
    compass?.cancel();
    super.dispose();
  }

  void updateCamera({bool force = false}) {
    final fix = app.currentFix;
    if (!app.foreground || fix == null || !loaded || !follow || app.planning) {
      return;
    }
    final now = DateTime.now();
    force = force || resetNavigationZoom;
    if (!force && now.difference(lastCamera).inMilliseconds < 250) return;
    final old = controller?.cameraPosition;
    final headingFresh =
        headingTime != null && now.difference(headingTime!).inSeconds < 3;
    final bearing = headingUp && navigating && headingFresh
        ? cameraHeading.value ?? 0
        : 0.0;
    if (!force &&
        old != null &&
        distance(
              fix.point,
              GeoPoint(old.target.latitude, old.target.longitude),
            ) <
            1 &&
        angleDifference(bearing, old.bearing).abs() < 2) {
      return;
    }
    lastCamera = now;
    unawaited(
      controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(fix.point.lat, fix.point.lon),
            zoom: resetNavigationZoom
                ? navigationZoom
                : old?.zoom ?? navigationZoom,
            bearing: bearing,
          ),
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
    resetNavigationZoom = false;
  }

  Future<void> focusTrail() async {
    final points =
        app.focused?.points.toList() ??
        (app.showHistory
            ? app.history.expand((t) => t.points).toList()
            : <GeoPoint>[]);
    if (points.isEmpty) return;
    follow = false;
    var south = points.first.lat,
        north = south,
        west = points.first.lon,
        east = west;
    for (final p in points) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lon);
      east = math.max(east, p.lon);
    }
    await controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south - .0001, west - .0001),
          northeast: LatLng(north + .0001, east + .0001),
        ),
        left: 35,
        top: 130,
        right: 70,
        bottom: app.planning ? 270 : 160,
      ),
    );
  }

  Future<void> showPlace(Place place) async {
    follow = false;
    final e = place.extent;
    // Buildings and addresses have tiny extents: show their surroundings.
    if (e != null && (e.east - e.west > .01 || e.north - e.south > .01)) {
      await controller?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(e.south, e.west),
            northeast: LatLng(e.north, e.east),
          ),
          left: 30,
          top: 110,
          right: 70,
          bottom: 60,
        ),
      );
    } else {
      await controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.point.lat, place.point.lon),
          14,
        ),
      );
    }
  }

  Future<void> update() async {
    if (!loaded || !mounted) return;
    pending = true;
    if (updating) return;
    updating = true;
    try {
      while (pending && loaded && mounted) {
        pending = false;
        final c = controller!;
        if (!identical(renderedApproach, app.approach)) {
          await c.setGeoJsonSource(
            'approach',
            collection(lines(app.approach?.trail.segments ?? [])),
          );
          renderedApproach = app.approach;
        }
        if (!identical(renderedHistory, app.history) ||
            renderedShowHistory != app.showHistory) {
          await c.setGeoJsonSource(
            'history',
            collection([
              if (app.showHistory)
                for (final walk in app.history) ...lines(walk.segments),
            ]),
          );
          renderedHistory = app.history;
          renderedShowHistory = app.showHistory;
        }
        final recording = app.recorder?.current;
        if (renderedSamples != recording?.samples.length) {
          await c.setGeoJsonSource(
            'recording',
            collection(lines(recording?.segments ?? [])),
          );
          renderedSamples = recording?.samples.length;
        }
        final selected = app.focused?.id;
        if (!identical(renderedTrails, app.trails) ||
            renderedSelection != selected) {
          final focused = app.focused;
          await c.setGeoJsonSource(
            'selected',
            collection([
              // A walk shows the trail it followed beneath its own line.
              if (focused?.walk?.reference case final reference?)
                ...lines(reference.segments, color: referenceHex),
              ...lines(
                focused?.segments ?? [],
                color:
                    focused == null ||
                        focused.walk != null ||
                        app.stored(focused)
                    ? ownTrailHex
                    : catalogueHex,
              ),
            ]),
          );
          await c.setGeoJsonSource(
            'pois',
            collection([
              for (final p in app.pois)
                feature(
                  'Point',
                  [p.point.lon, p.point.lat],
                  {'name': p.name, 'description': p.description},
                ),
            ]),
          );
          renderedTrails = app.trails;
          renderedSelection = selected;
          renderedDays = null;
        }
        if (!identical(renderedDays, app.days) ||
            !identical(renderedApproachMarkers, app.approach) ||
            renderedStart != app.draftStart ||
            renderedEnd != app.draftEnd ||
            renderedPlanning != app.planning) {
          final geometry = app.focused == null
              ? null
              : TrailGeometry(app.focused!);
          final portions = <Map<String, dynamic>>[];
          final markers = <Map<String, dynamic>>[];
          if (app.approach != null && app.approachDestination != null) {
            final end = app.approachDestination!;
            markers.add(
              feature(
                'Point',
                [end.lon, end.lat],
                {'label': 'R', 'color': '#2563eb'},
              ),
            );
          }
          if (geometry != null) {
            for (var i = 0; i < app.days.length; i++) {
              final day = app.days[i];
              portions.addAll(
                lines(
                  geometry.portion(day.start, day.end),
                  color: dayColors[i % dayColors.length],
                ),
              );
              final p = geometry.pointAt(day.end);
              if (p != null) {
                markers.add(
                  feature(
                    'Point',
                    [p.lon, p.lat],
                    {
                      'label': '${i + 1}',
                      'color': dayColors[i % dayColors.length],
                    },
                  ),
                );
              }
            }
            if (app.planning) {
              if (app.draftStart != null && app.draftEnd != null) {
                portions.addAll(
                  lines(
                    geometry.portion(app.draftStart!, app.draftEnd!),
                    color: '#ec9f05',
                  ),
                );
              }
              for (final entry in {
                'A': app.draftStart,
                'B': app.draftEnd,
              }.entries) {
                final p = entry.value == null
                    ? null
                    : geometry.pointAt(entry.value!);
                if (p != null) {
                  markers.add(
                    feature(
                      'Point',
                      [p.lon, p.lat],
                      {'label': entry.key, 'color': '#a76b00'},
                    ),
                  );
                }
              }
            }
          }
          await c.setGeoJsonSource('days', collection(portions));
          this.markers = markers;
          unawaited(projectMarkers());
          renderedDays = app.days;
          renderedStart = app.draftStart;
          renderedEnd = app.draftEnd;
          renderedPlanning = app.planning;
          renderedApproachMarkers = app.approach;
        }
        final fix = app.currentFix;
        final reliable = fix?.reliable(DateTime.now()) ?? false;
        // With a fresh compass heading the arrow replaces the dot, so the
        // position is drawn once and the direction is unambiguous.
        final heading =
            fix != null &&
                reliable &&
                navigating &&
                pointer.value != null &&
                headingTime != null &&
                DateTime.now().difference(headingTime!).inSeconds < 3
            ? pointer.value
            : null;
        await c.setGeoJsonSource(
          'position',
          collection([
            if (fix != null && heading == null)
              feature(
                'Point',
                [fix.point.lon, fix.point.lat],
                {'color': reliable ? '#2563eb' : '#808b94'},
              ),
          ]),
        );
        final zoom = c.cameraPosition?.zoom ?? navigationZoom;
        await c.setGeoJsonSource(
          'heading',
          collection([
            if (fix != null && heading != null)
              ...positionArrowFeatures(
                fix.point,
                heading,
                metresPerPixel(zoom, fix.point.lat),
              ),
          ]),
        );
        arrowZoom = heading == null ? null : zoom;
        final active = navigating;
        final starting =
            active &&
            (!wasActive ||
                (app.session?.active == true &&
                    !identical(followedSession, app.session)));
        if (focusRevision != app.focusRevision) {
          focusRevision = app.focusRevision;
          if (!starting || app.planning) await focusTrail();
        }
        if (starting && !app.planning) {
          follow = true;
          resetNavigationZoom = true;
        }
        if (placeRevision != app.placeRevision) {
          placeRevision = app.placeRevision;
          if (app.placeTarget case final place?) await showPlace(place);
        }
        if (!identical(anchoredTrails, app.pinned) ||
            anchoredPins != showPins ||
            anchoredFocus != app.focused?.id) {
          unawaited(refreshAnchors());
        }
        wasActive = active;
        followedSession = app.session?.active == true ? app.session : null;
        updateCamera();
      }
    } catch (e) {
      if (mounted && loaded) debugPrint('Map update: $e');
    } finally {
      updating = false;
    }
  }

  Future<void> styleLoaded() async {
    loaded = false;
    renderedTrails = renderedDays = null;
    anchoredTrails = anchoredPins = anchoredFocus = null;
    renderedHistory = null;
    renderedApproach = null;
    renderedShowHistory = null;
    renderedSamples = -1;
    final c = controller!;
    for (final id in [
      'selected',
      'days',
      'ends',
      'pois',
      'position',
      'heading',
      'history',
      'recording',
      'approach',
    ]) {
      await c.addGeoJsonSource(id, collection([]));
    }
    await c.addLineLayer(
      'selected',
      'selected-halo',
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: 9,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await c.addLineLayer(
      'selected',
      'selected-line',
      const LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 5,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await c.addLineLayer(
      'history',
      'history-lines',
      const LineLayerProperties(
        lineColor: '#c66a25',
        lineWidth: 4,
        lineOpacity: .8,
      ),
      enableInteraction: false,
    );
    await c.addLineLayer(
      'recording',
      'recording-line',
      const LineLayerProperties(lineColor: '#277cc1', lineWidth: 4),
      enableInteraction: false,
    );
    await c.addLineLayer(
      'days',
      'day-lines',
      const LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 7,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await c.addLineLayer(
      'approach',
      'approach-line',
      const LineLayerProperties(
        lineColor: '#2563eb',
        lineWidth: 6,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await c.addCircleLayer(
      'pois',
      'poi-dots',
      const CircleLayerProperties(
        circleRadius: 7,
        circleColor: '#d47b37',
        circleStrokeWidth: 2,
        circleStrokeColor: '#ffffff',
      ),
      enableInteraction: false,
    );
    for (final (source, color, image) in [
      (ownPinSource, ownTrailHex, ownPinImage),
      (cataloguePinSource, catalogueHex, cataloguePinImage),
    ]) {
      final prefix = source.replaceFirst('-pins', '');
      await c.addSource(
        source,
        GeojsonSourceProperties(
          data: collection([]),
          cluster: true,
          clusterRadius: 48,
          clusterMaxZoom: 15,
        ),
      );
      // A group reads as a group: a soft halo around a counted bubble whose
      // size grows with the count, in the style of its trails' pins.
      const radius = [
        'step',
        ['get', 'point_count'],
        16,
        10,
        19,
        50,
        23,
        200,
        27,
      ];
      await c.addCircleLayer(
        source,
        '$prefix-pin-halos',
        CircleLayerProperties(
          circleColor: color,
          circleOpacity: .2,
          circleRadius: ['+', radius, 7],
        ),
        filter: ['has', 'point_count'],
        enableInteraction: false,
      );
      final catalogue = source == cataloguePinSource;
      await c.addCircleLayer(
        source,
        '$prefix-pin-clusters',
        CircleLayerProperties(
          circleColor: catalogue ? '#ffffff' : color,
          circleRadius: radius,
          circleStrokeColor: catalogue ? color : '#ffffff',
          circleStrokeWidth: 3,
        ),
        filter: ['has', 'point_count'],
        enableInteraction: false,
      );
      await c.addSymbolLayer(
        source,
        '$prefix-pin-counts',
        SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textFont: const ['Noto Sans Bold'],
          textSize: 14,
          textColor: catalogue ? color : '#ffffff',
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        filter: ['has', 'point_count'],
        enableInteraction: false,
      );
      try {
        await c.addImage(image, await (catalogue ? cataloguePin : ownPin));
      } catch (e) {
        debugPrint('Pin image: $e');
      }
      // Single pins always show; their length label shows where it fits.
      await c.addSymbolLayer(
        source,
        '$prefix-pin-points',
        SymbolLayerProperties(
          iconImage: image,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          textField: ['get', 'label'],
          textFont: const ['Noto Sans Bold'],
          textSize: 11,
          textAnchor: 'top',
          textOffset: const [0, 1.45],
          textColor: color,
          textHaloColor: '#ffffff',
          textHaloWidth: 1.6,
          textOptional: true,
        ),
        filter: [
          '!',
          ['has', 'point_count'],
        ],
        enableInteraction: false,
      );
    }
    await c.addCircleLayer(
      'position',
      'position-dot',
      const CircleLayerProperties(
        circleRadius: 7,
        circleColor: ['get', 'color'],
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
      ),
      enableInteraction: false,
    );
    const beam = [
      '==',
      ['get', 'part'],
      'beam',
    ];
    const chevron = [
      '==',
      ['get', 'part'],
      'arrow',
    ];
    await c.addFillLayer(
      'heading',
      'heading-beam',
      const FillLayerProperties(
        fillColor: positionArrowHex,
        fillOpacity: ['get', 'opacity'],
        fillAntialias: false,
      ),
      filter: beam,
      enableInteraction: false,
    );
    await c.addLineLayer(
      'heading',
      'heading-shadow',
      const LineLayerProperties(
        lineColor: '#000000',
        lineOpacity: .22,
        lineWidth: 7,
        lineBlur: 3,
        lineJoin: 'round',
      ),
      filter: chevron,
      enableInteraction: false,
    );
    await c.addLineLayer(
      'heading',
      'heading-rim',
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: 4.5,
        lineJoin: 'round',
      ),
      filter: chevron,
      enableInteraction: false,
    );
    await c.addFillLayer(
      'heading',
      'heading-arrow',
      const FillLayerProperties(fillColor: positionArrowHex),
      filter: chevron,
      enableInteraction: false,
    );
    if (!mounted) return;
    loaded = true;
    await update();
  }

  Future<void> tap(math.Point<double> screen, LatLng coordinate) async {
    if (!loaded) return;
    final p = GeoPoint(coordinate.latitude, coordinate.longitude);
    final zoom = controller?.cameraPosition?.zoom ?? 15;
    final tolerance =
        24 * 156543.03392 * math.cos(p.lat * math.pi / 180) / math.pow(2, zoom);
    if (app.planning && app.focused != null) {
      final trailId = app.focused!.id;
      final candidates = TrailGeometry(app.focused!)
          .pickCandidates(p, math.min(tolerance, 100));
      if (candidates.isNotEmpty) {
        final chosen = candidates.length == 1
            ? candidates.first
            : await showModalBottomSheet<Projection>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(context.l10n.chooseTrailPassage),
                      ),
                      for (final candidate in candidates)
                        ListTile(
                          title: Text(
                            context.l10n.atGpxKilometre(
                              decimal(candidate.along / 1000, 2),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, candidate),
                        ),
                    ],
                  ),
                ),
              );
        if (chosen != null && app.planning && app.focused?.id == trailId) {
          app.placeBoundary(chosen.along);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.tapSelectedTrail),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (await tapPin(screen)) return;
    final nearPlaces = app.visiblePlaces
        .where((place) => distance(p, place.point) <= tolerance)
        .toList();
    if (nearPlaces.isNotEmpty && mounted) {
      await showTrailPlace(context, app, nearPlaces.first);
      return;
    }
    final nearPois = app.pois
        .where((poi) => distance(p, poi.point) <= tolerance)
        .toList();
    if (nearPois.isNotEmpty && mounted) {
      final poi = nearPois.first;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListTile(
            title: Text(poi.name),
            subtitle: Text(poi.description),
          ),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final point =
        app.currentFix?.point ??
        app.trails.firstOrNull?.points.firstOrNull ??
        app.pois.firstOrNull?.point ??
        const GeoPoint(43.163, -1.237);
    final style =
        app.mapStyle ??
        jsonEncode({
          'version': 8,
          'sources': <String, dynamic>{},
          'layers': [
            {
              'id': 'background',
              'type': 'background',
              'paint': {'background-color': '#e8ecdf'},
            },
          ],
        });
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) => follow = false,
          child: MapLibreMap(
            styleString: style,
            initialCameraPosition: CameraPosition(
              target: LatLng(point.lat, point.lon),
              zoom: 16,
            ),
            onMapCreated: (c) => controller = c,
            onStyleLoadedCallback: styleLoaded,
            onMapClick: tap,
            // Pins move with the map natively; only day labels are placed here.
            onCameraMove: (position) {
              if (markers.isNotEmpty) unawaited(projectMarkers());
              // The arrow is drawn in ground units: resize it on zoom.
              final sized = arrowZoom;
              if (sized != null && (position.zoom - sized).abs() > .05) {
                arrowZoom = position.zoom;
                unawaited(update());
              }
            },
            trackCameraPosition: true,
            onCameraIdle: () async {
              unawaited(refreshAnchors());
              final c = controller;
              if (c == null || !mounted) return;
              final bounds = await c.getVisibleRegion();
              if (!mounted) return;
              // Catalogue trails of the new view, loaded from the server.
              unawaited(
                app.browseArea(
                  Bounds(
                    bounds.southwest.longitude,
                    bounds.southwest.latitude,
                    bounds.northeast.longitude,
                    bounds.northeast.latitude,
                  ),
                ),
              );
              try {
                await app.automaticMaps?.viewport(
                  Bounds(
                    bounds.southwest.longitude,
                    bounds.southwest.latitude,
                    bounds.northeast.longitude,
                    bounds.northeast.latitude,
                  ),
                  c.cameraPosition?.zoom ?? 16,
                );
              } catch (_) {
                /* Preparation reports storage failures. */
              }
            },
            compassEnabled: false,
            attributionButtonPosition: AttributionButtonPosition.topRight,
            attributionButtonMargins: const math.Point(12, 130),
          ),
        ),
        for (final marker in markerViews)
          Positioned(
            left:
                marker.point.x /
                    (defaultTargetPlatform == TargetPlatform.android
                        ? MediaQuery.devicePixelRatioOf(context)
                        : 1) -
                14,
            top:
                marker.point.y /
                    (defaultTargetPlatform == TargetPlatform.android
                        ? MediaQuery.devicePixelRatioOf(context)
                        : 1) -
                14,
            child: IgnorePointer(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(
                    int.parse(marker.color.replaceFirst('#', 'ff'), radix: 16),
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  marker.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'orientation',
                tooltip: headingUp
                    ? context.l10n.northUp
                    : context.l10n.headingUp,
                backgroundColor: Colors.white,
                onPressed: () {
                  setState(() => headingUp = !headingUp);
                  follow = true;
                  updateCamera(force: true);
                },
                child: Icon(headingUp ? Icons.explore : Icons.north),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'recenter',
                tooltip: context.l10n.recenter,
                backgroundColor: Colors.white,
                onPressed: () {
                  follow = true;
                  resetNavigationZoom = true;
                  unawaited(app.browseLocation());
                  updateCamera(force: true);
                },
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
