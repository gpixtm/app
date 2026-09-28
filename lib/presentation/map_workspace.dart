import 'localization.dart';

import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import 'design.dart';
import 'elevation_chart.dart';
import '../domain/trail_geometry.dart';
import '../domain/walk_metrics.dart';
import 'guidance_text.dart';
import 'place_search_bar.dart';
import 'trail_map.dart';
import 'trail_details.dart';
import 'trail_places.dart';
import 'trail_reviews.dart';
import 'walk_controls.dart';
import 'walk_stats.dart';
import 'join_departure.dart';

class MapWorkspace extends StatefulWidget {
  const MapWorkspace(
    this.app, {
    required this.openLibrary,
    required this.importTrails,
    this.mapBuilder,
    super.key,
  });
  final AppController app;
  final VoidCallback openLibrary, importTrails;
  final Widget Function(AppController)? mapBuilder;
  @override
  State<MapWorkspace> createState() => _MapWorkspaceState();
}

class _MapWorkspaceState extends State<MapWorkspace> {
  final sheet = DraggableScrollableController();

  /// Trails sharing the pin the walker touched, listed in the bottom panel.
  List<Trail>? cluster;
  AppController get app => widget.app;
  void openMenu() => Scaffold.of(context).openDrawer();
  void showTrail(Trail trail) {
    setState(() => cluster = null);
    app.open(trail);
  }

  @override
  void dispose() {
    sheet.dispose();
    super.dispose();
  }

  void toggleSheet() {
    if (!sheet.isAttached) return;
    sheet.animateTo(
      sheet.size > .3 ? .19 : .62,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void details() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StreamBuilder<void>(
        stream: app.changes.stream,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.focused?.name ?? context.l10n.myMap,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                app.focused != null && app.covers(app.focused!)
                    ? context.l10n.trailMapAvailable
                    : context.l10n.visibleMapsInfo,
              ),
              const SizedBox(height: 8),
              Text(context.message(app.mapStatus)),
              const SizedBox(height: 12),
              Text(context.l10n.offlineMapsInfo),
              if (app.session?.active == true) ...[
                const Divider(),
                Text(context.l10n.activeTrail(app.selected?.name ?? "")),
                Text(context.l10n.compassInfo),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> leavePlanning() async {
    if (app.draftEnd != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(context.l10n.discardChangesQuestion),
          content: Text(context.l10n.discardChangesInfo),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(context.l10n.continueAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(context.l10n.leave),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    app.finishPlanning();
  }

  Future<void> removeDay(int index) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteDayQuestion(index + 1)),
        content: Text(context.l10n.deleteDayInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (yes == true) await app.deleteDay(index);
  }

  Widget metric(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xff627068)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final trail = app.focused;
    final s = app.selected?.id == trail?.id ? app.session : null;
    final p = s?.projection, fix = s?.fix;
    final approach = s != null ? app.approach : null;
    final direction = approach?.next(p?.along ?? 0);
    final upcoming = app.approach == null ? app.upcomingManeuver : null;
    final turn = upcoming != null && upcoming.metres <= 500 ? upcoming : null;
    final exploring = trail == null && !app.planning;
    // The followed trail stays on screen until tracking is paused.
    final closable =
        trail != null &&
        !app.planning &&
        !(app.session?.active == true && app.selected?.id == trail.id);
    final leading = closable
        ? IconButton(
            tooltip: context.l10n.closeTrail,
            onPressed: app.closeTrail,
            icon: const Icon(Icons.arrow_back),
          )
        : IconButton(
            tooltip: context.l10n.menu,
            onPressed: openMenu,
            icon: const Icon(Icons.menu),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.mapBuilder?.call(app) ??
            TrailMap(
              app,
              key: ValueKey(app.mapVersion),
              onPin: (trails) => trails.length == 1
                  ? showTrail(trails.single)
                  : setState(() => cluster = trails),
            ),
        if (!exploring)
          Positioned(
            top: 12,
            left: 12,
            right: 76,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: details,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 14, 4),
                  child: turn != null
                      ? Semantics(
                          label: context.l10n.nextDirection,
                          child: Row(
                            children: [
                              leading,
                              Icon(
                                guidanceIcon(turn.kind),
                                color: forest,
                                size: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guidanceTitle(context.l10n, turn.kind),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.inMetres(
                                        turn.metres.round(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.info_outline, size: 18),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            leading,
                            Icon(
                              trail != null &&
                                      app.covers(app.approach?.trail ?? trail)
                                  ? Icons.offline_pin
                                  : Icons.map_outlined,
                              color: forest,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (app.approach != null
                                        ? context.l10n.towardsTrail(
                                            app.selected?.name ?? '',
                                          )
                                        : trail?.name) ??
                                    context.l10n.myMap,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
        if (app.recorder?.current != null)
          Positioned(
            top: 70,
            left: 12,
            right: 76,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(
                  app.recorder!.active
                      ? Icons.fiber_manual_record
                      : Icons.pause,
                  size: 16,
                  color: app.recorder!.active ? Colors.red : Colors.grey,
                ),
                label: Text(
                  app.recorder!.active
                      ? context.l10n.walkInProgressData
                      : context.l10n.walkPausedResume,
                ),
                onPressed: toggleSheet,
              ),
            ),
          ),
        if (app.showHistory)
          Positioned(
            top: app.recorder?.current == null ? 70 : 112,
            left: 12,
            child: InputChip(
              label: Text(context.l10n.walkedPlaces),
              onDeleted: () {
                app.showHistory = false;
                app.notifyListeners();
              },
            ),
          ),
        if (!app.planning &&
            app.session?.offTrail == true &&
            app.session?.muted == false)
          Positioned(
            top: app.showHistory ? 154 : 112,
            left: 12,
            right: 76,
            child: ActionChip(
              backgroundColor: const Color(0xffffe6c8),
              avatar: const Icon(Icons.wrong_location_outlined),
              label: Text(context.l10n.offTrailDetails),
              onPressed: toggleSheet,
            ),
          ),
        if (exploring)
          Positioned(
            top: 12,
            left: 12,
            right: 76,
            child: PlaceSearchBar(app, openMenu: openMenu),
          ),
        if (app.planning)
          DraggableScrollableSheet(
            key: const ValueKey('planner'),
            initialChildSize: .39,
            minChildSize: .32,
            maxChildSize: .78,
            builder: (context, scroll) => panel(
              ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  handle(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.editingDay == null
                              ? context.l10n.dayNumber(app.days.length + 1)
                              : context.l10n.editDayNumber(app.editingDay! + 1),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: app.busy ? null : leavePlanning,
                        child: Text(context.l10n.finish),
                      ),
                    ],
                  ),
                  Text(
                    app.pickingStart
                        ? context.l10n.tapStart
                        : app.draftEnd == null
                        ? context.l10n.tapEnd
                        : context.l10n.reviewSection,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          context.l10n.startBoundary(
                            app.draftStart == null
                                ? ""
                                : " · ${kilometers(app.draftStart!)}",
                          ),
                        ),
                        selected: app.pickingStart,
                        onSelected: app.busy
                            ? null
                            : (_) => app.pickBoundary(true),
                      ),
                      ChoiceChip(
                        label: Text(
                          context.l10n.endBoundary(
                            app.draftEnd == null
                                ? ""
                                : " · ${kilometers(app.draftEnd!)}",
                          ),
                        ),
                        selected: !app.pickingStart,
                        onSelected: app.busy
                            ? null
                            : (_) => app.pickBoundary(false),
                      ),
                    ],
                  ),
                  if (app.draftStart != null && app.draftEnd != null)
                    Text(
                      context.l10n.minimumSection(
                        kilometers((app.draftEnd! - app.draftStart!).abs()),
                        app.draftEnd! < app.draftStart!
                            ? context.l10n.reverseSuffix
                            : "",
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: app.draftValid && !app.busy ? app.saveDay : null,
                    icon: const Icon(Icons.check),
                    label: Text(
                      app.editingDay == null
                          ? context.l10n.saveDay
                          : context.l10n.saveChanges,
                    ),
                  ),
                  TextButton(
                    onPressed: app.busy ? null : app.nextDay,
                    child: Text(
                      app.editingDay == null
                          ? context.l10n.continueFromLastEnd
                          : context.l10n.cancelEdit,
                    ),
                  ),
                  const Divider(),
                  Text(
                    context.l10n.myDays,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.message(app.syncStatus),
                    style: TextStyle(fontSize: 12),
                  ),
                  if (app.days.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.l10n.noDays),
                    ),
                  for (var i = 0; i < app.days.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(
                          int.parse(
                            dayColors[i % dayColors.length].replaceFirst(
                              '#',
                              'ff',
                            ),
                            radix: 16,
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        context.l10n.dayDistance(
                          i + 1,
                          kilometers(app.days[i].length),
                        ),
                      ),
                      subtitle: Text(
                        '${kilometers(app.days[i].start)} → ${kilometers(app.days[i].end)}',
                      ),
                      onTap: app.busy ? null : () => app.editDay(i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.l10n.editDayNumber(i + 1),
                            onPressed: app.busy ? null : () => app.editDay(i),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: context.l10n.deleteDayNumber(i + 1),
                            onPressed: app.busy ? null : () => removeDay(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (cluster != null)
          DraggableScrollableSheet(
            key: const ValueKey('cluster'),
            initialChildSize: .36,
            minChildSize: .2,
            maxChildSize: .72,
            builder: (context, scroll) => panel(
              ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  handle(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.trailsHere(cluster!.length),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.close,
                        onPressed: () => setState(() => cluster = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  for (final t in cluster!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: app.stored(t)
                            ? const Color(0xffedf1e7)
                            : const Color(0xffefe8f6),
                        child: Icon(
                          app.stored(t) ? Icons.hiking : Icons.travel_explore,
                          color: app.stored(t) ? forest : catalogueColor,
                        ),
                      ),
                      title: Text(t.name),
                      subtitle: Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            kilometers(
                              app.sharedFor(t)?.metres ??
                                  TrailGeometry(t).total,
                            ),
                          ),
                          if (app.sharedFor(t) case final shared?
                              when shared.reviews > 0)
                            RatingSummary(
                              count: shared.reviews,
                              average: shared.average,
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showTrail(t),
                    ),
                ],
              ),
            ),
          )
        else if (trail != null)
          DraggableScrollableSheet(
            key: const ValueKey('navigation'),
            controller: sheet,
            initialChildSize: .22,
            minChildSize: .16,
            maxChildSize: .72,
            snap: true,
            snapSizes: const [.22, .62],
            builder: (context, scroll) => panel(
              ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  InkWell(
                    onTap: toggleSheet,
                    child: Column(
                      children: [
                        handle(),
                        Row(
                          children: [
                            // Following: what is left. Browsing: the trail's
                            // own length and climb, the first things to know.
                            if (s?.active == true || approach != null) ...[
                              metric(
                                p == null || s == null
                                    ? '—'
                                    : kilometers(
                                        s.geometry.remaining(p, s.reverse),
                                      ),
                                context.l10n.remaining,
                              ),
                              metric(
                                p == null ? '—' : '${p.offTrail.round()} m',
                                context.l10n.distanceToTrail,
                              ),
                            ] else if (WalkMetrics(trail)
                                case final metrics) ...[
                              metric(
                                kilometers(metrics.metres),
                                context.l10n.trailDistance,
                              ),
                              metric(
                                metrics.maximumAltitude == null
                                    ? '—'
                                    : '${metrics.ascent.round()} m',
                                context.l10n.trailAscent,
                              ),
                            ],
                            IconButton(
                              tooltip: context.l10n.toggleDetails,
                              onPressed: toggleSheet,
                              icon: const Icon(Icons.unfold_more),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The walk being recorded is controlled here, alongside the
                  // trail, rather than from the history screen.
                  if (app.recorder?.current != null) ...[
                    RecordingStatus(app),
                    const SizedBox(height: 8),
                    WalkControls(app),
                    const SizedBox(height: 12),
                  ],
                  if (approach != null) ...[
                    if (app.atConnection)
                      ListTile(
                        leading: Icon(Icons.flag),
                        title: Text(context.l10n.trailReached),
                        subtitle: Text(context.l10n.readyToFollow),
                      )
                    else if (fix == null || !fix.reliable(DateTime.now()))
                      Text(context.l10n.findingAccuratePosition)
                    else if (p != null &&
                        (s?.geometry.total ?? double.infinity) - p.along < 30 &&
                        app.approachDestination != null)
                      Text(
                        context.l10n.routeEndGap(
                          distance(fix.point, app.approachDestination!).round(),
                        ),
                      )
                    else if (s?.offTrail == true)
                      Text(context.l10n.leftApproach)
                    else if (direction != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.directions_walk),
                        title: Text(direction.instruction),
                        subtitle: Text(
                          context.l10n.inMetres(
                            (direction.along - (p?.along ?? 0))
                                .clamp(0, double.infinity)
                                .round(),
                          ),
                        ),
                      ),
                    if (app.atConnection)
                      FilledButton.icon(
                        onPressed: app.busy ? null : app.startOriginalTrail,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(context.l10n.followFromHere),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: app.busy
                              ? null
                              : () => app.joinTrail(
                                  trail,
                                  reverse: app.approachReverse,
                                ),
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.recalculate),
                        ),
                        TextButton(
                          onPressed: app.busy ? null : app.cancelApproach,
                          child: Text(context.l10n.exitApproach),
                        ),
                      ],
                    ),
                    Text(
                      approach.cached
                          ? context.l10n.cachedRouteInfo
                          : context.l10n.savedWalkingApproach,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => openDirectionsLink(
                            context,
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                          child: Text(context.l10n.routingAttribution),
                        ),
                        TextButton(
                          onPressed: () => openDirectionsLink(
                            context,
                            Uri.parse(
                              'https://www.openstreetmap.org/fixthemap',
                            ),
                          ),
                          child: Text(context.l10n.fixMap),
                        ),
                      ],
                    ),
                  ],
                  if (trail.followable && trail.walk == null)
                    FilledButton.icon(
                      onPressed: app.busy
                          ? null
                          : () async {
                              if (s?.active == true) {
                                app.stop();
                              } else if (approach != null) {
                                await app.start();
                              } else {
                                // Joins the trail by an internal walking
                                // route first when the walker is elsewhere.
                                await app.launch(trail);
                              }
                            },
                      icon: Icon(
                        s?.active == true ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(
                        s?.active == true
                            ? context.l10n.pauseTracking
                            : approach != null
                            ? context.l10n.resumeApproach
                            : context.l10n.followTrail,
                      ),
                    ),
                  if (trail.followable &&
                      trail.walk == null &&
                      !(s?.active == true && approach == null)) ...[
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: app.busy
                          ? null
                          : () => openInGoogleMaps(context, app, trail),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: Text(context.l10n.openInGoogleMaps),
                    ),
                    if (s?.active != true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          context.l10n.routingPrivacy,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff627068),
                          ),
                        ),
                      ),
                  ],
                  if (trail.followable &&
                      trail.walk == null &&
                      app.collaborative != null &&
                      approach == null &&
                      s?.active != true)
                    TrailKeepActions(app, trail),
                  // Where the walker stands: a viewpoint, a spring…
                  if (trail.followable &&
                      trail.walk == null &&
                      approach == null &&
                      app.collaborative != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: app.busy
                            ? null
                            : () => addPlaceHere(context, app, trail),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(context.l10n.addPlaceHere),
                      ),
                    ),
                  if (trail.walk == null &&
                      s?.active != true &&
                      approach == null &&
                      app.collaborative != null)
                    TrailDetailsSection(app, trail),
                  if (trail.followable &&
                      trail.walk == null &&
                      s?.active != true &&
                      approach == null)
                    TrailReviewsSection(app, trail),
                  if (app.session?.active == true && s == null)
                    TextButton(
                      onPressed: () => app.focus(app.selected!),
                      child: Text(
                        context.l10n.returnToTracking(app.selected!.name),
                      ),
                    ),
                  if (s?.active == true)
                    Text(
                      fix == null
                          ? context.l10n.findingPosition
                          : !fix.reliable(DateTime.now())
                          ? context.l10n.poorGps
                          : context.l10n.gpsAccuracy(fix.accuracy.round()),
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (app.session?.offTrail == true &&
                      app.session?.muted == false)
                    Card(
                      color: const Color(0xffffe6c8),
                      child: ListTile(
                        title: Text(context.l10n.leavingTrail),
                        trailing: TextButton(
                          onPressed: app.mute,
                          child: Text(context.l10n.muteAlert),
                        ),
                      ),
                    ),
                  if (s != null && approach == null) ...[
                    ElevationChart(
                      geometry: s.geometry,
                      projection: p,
                      reverse: s.reverse,
                      estimated: trail.estimated,
                    ),
                    TextButton.icon(
                      onPressed: app.invert,
                      icon: const Icon(Icons.swap_vert),
                      label: Text(
                        s.reverse
                            ? context.l10n.reverseDirection
                            : context.l10n.gpxDirection,
                      ),
                    ),
                  ],
                  if (app.recorder?.current != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.currentWalk,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    WalkStats(app.recorder!.current!.snapshot(DateTime.now())),
                    OutlinedButton.icon(
                      onPressed: app.busy || app.health == null
                          ? null
                          : () => app.importHealth(
                              app.recorder!.current!.snapshot(DateTime.now()),
                            ),
                      icon: const Icon(Icons.watch_outlined),
                      label: Text(context.l10n.importWatchData),
                    ),
                  ],
                  if (trail.walk != null) WalkStats(trail),
                  if (app.recorder != null &&
                      app.recorder!.current == null &&
                      s?.active != true &&
                      approach == null)
                    TextButton.icon(
                      onPressed: app.busy
                          ? null
                          : () {
                              app.closeTrail();
                              app.freeWalk();
                            },
                      icon: const Icon(Icons.route),
                      label: Text(context.l10n.startRoute),
                    ),
                  if (trail.followable && trail.walk == null)
                    OutlinedButton.icon(
                      onPressed: app.busy
                          ? null
                          : () => app.beginPlanning(trail),
                      icon: const Icon(Icons.edit_road),
                      label: Text(
                        app.days.isEmpty
                            ? context.l10n.planDays
                            : context.l10n.editDays(app.days.length),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: details,
                    icon: const Icon(Icons.offline_pin_outlined),
                    label: Text(context.l10n.offlineAvailability),
                  ),
                  TextButton(
                    onPressed: widget.openLibrary,
                    child: Text(context.l10n.myTrails),
                  ),
                ],
              ),
            ),
          )
        else if (app.recorder?.current != null)
          DraggableScrollableSheet(
            key: const ValueKey('recording'),
            controller: sheet,
            initialChildSize: .22,
            minChildSize: .16,
            maxChildSize: .75,
            builder: (context, scroll) => panel(
              ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  handle(),
                  Text(
                    recordingRoute(app)
                        ? context.l10n.routeInProgress
                        : context.l10n.currentWalk,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  RecordingStatus(app),
                  const SizedBox(height: 8),
                  WalkControls(app),
                  const SizedBox(height: 12),
                  WalkStats(app.recorder!.current!.snapshot(DateTime.now())),
                  OutlinedButton.icon(
                    onPressed: app.busy || app.health == null
                        ? null
                        : () => app.importHealth(
                            app.recorder!.current!.snapshot(DateTime.now()),
                          ),
                    icon: const Icon(Icons.watch_outlined),
                    label: Text(context.l10n.importWatchData),
                  ),
                ],
              ),
            ),
          )
        else if (app.trails.isEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.mapAroundYou),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: app.busy ? null : widget.importTrails,
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.importGpx),
                    ),
                    if (app.recorder != null)
                      TextButton.icon(
                        onPressed: app.busy ? null : app.freeWalk,
                        icon: const Icon(Icons.route),
                        label: Text(context.l10n.startRoute),
                      ),
                  ],
                ),
              ),
            ),
          )
        else if (app.recorder != null)
          Positioned(
            left: 12,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'free-walk',
              backgroundColor: Colors.white,
              foregroundColor: forest,
              onPressed: app.busy ? null : app.freeWalk,
              icon: const Icon(Icons.route),
              label: Text(context.l10n.startRoute),
            ),
          ),
      ],
    );
  }

  Widget handle() => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
  Widget panel(Widget child) => Material(
    color: Colors.white,
    elevation: 8,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
