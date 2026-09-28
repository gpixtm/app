import 'localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/route_history.dart';
import 'design.dart';
import 'history_charts.dart';
import 'route_history_page.dart';
import 'walk_controls.dart';
import 'walk_stats.dart';

/// Walk A, and the walk shown alone: the colour of recorded walks.
const walkColor = Color(0xffc66a25);

/// Walk B of a comparison.
const otherWalkColor = Color(0xff2f6db5);
const referenceColor = Color(0xff8fa89c);

String speedLabel(double kmh) => '${decimal(kmh)} km/h';

/// A signed difference with a true minus sign: "+0.2", "−1.5".
String signed(num value, [int digits = 1]) {
  final text = decimal(value.abs(), digits);
  return value > 0
      ? '+$text'
      : value < 0
      ? '−$text'
      : text;
}

/// "3 Aug", or "3 Aug 2025" outside the current year.
String shortDate(BuildContext context, DateTime value) {
  final d = value.toLocal(), locale = context.l10n.localeName;
  return d.year == DateTime.now().year
      ? DateFormat.MMMd(locale).format(d)
      : DateFormat.yMMMd(locale).format(d);
}

class HistoryView extends StatefulWidget {
  const HistoryView(
    this.app, {
    required this.openMap,
    required this.openSettings,
    super.key,
  });
  final AppController app;
  final VoidCallback openMap, openSettings;
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  int filter = 0;
  String query = '';
  AppController get app => widget.app;

  // Measuring walks against their routes is reused until either list changes.
  List<Trail>? _walks, _library;
  List<RouteHistory> _routes = const [];
  final measures = RouteMeasures();
  List<RouteHistory> get routes {
    if (!identical(_walks, app.history) || !identical(_library, app.trails)) {
      _walks = app.history;
      _library = app.trails;
      _routes = groupWalks(app.history, app.trails, measures: measures);
    }
    return _routes;
  }

  void open(RouteHistory route) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RouteHistoryPage(
        app,
        routeId: route.id,
        measures: measures,
        openMap: widget.openMap,
        openSettings: widget.openSettings,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ongoing = app.recorder?.current;
    final search = foldForSearch(query.trim());
    final all = routes;
    final items = all
        .where((r) => filter == 0 || (filter == 1 ? !r.free : r.free))
        .where((r) => search.isEmpty || foldForSearch(r.name).contains(search))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(context.l10n.walkHistoryInfo),
        const SizedBox(height: 18),
        // Recording is controlled from the map's bottom panel; history only
        // points back to it.
        if (ongoing != null)
          Card(
            child: ListTile(
              title: RecordingStatus(app),
              subtitle: Text(ongoing.saved.name),
              trailing: FilledButton.tonalIcon(
                onPressed: widget.openMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(context.l10n.map),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          context.l10n.routeHistoryCount(
            all.length,
            app.history.length,
            kilometers(all.fold<double>(0, (sum, r) => sum + r.metres)),
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          context.message(app.syncStatus),
          style: const TextStyle(fontSize: 12),
        ),
        TextButton.icon(
          onPressed: app.history.isEmpty
              ? null
              : () {
                  app.viewHistory();
                  widget.openMap();
                },
          icon: const Icon(Icons.layers_outlined),
          label: Text(context.l10n.viewAllWalkedPlaces),
        ),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(context.l10n.allWalks)),
            ButtonSegment(value: 1, label: Text(context.l10n.withGpx)),
            ButtonSegment(value: 2, label: Text(context.l10n.freeWalks)),
          ],
          selected: {filter},
          onSelectionChanged: (v) => setState(() => filter = v.single),
        ),
        if (all.length > 3) ...[
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.l10n.searchRoutes,
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              all.isEmpty
                  ? context.l10n.noWalks
                  : context.l10n.noMatchingRoutes,
            ),
          ),
        for (final route in items)
          RouteHistoryCard(route, onTap: () => open(route)),
      ],
    );
  }
}

/// One route of the history: its last walk, its record and its trend.
class RouteHistoryCard extends StatelessWidget {
  const RouteHistoryCard(this.route, {required this.onTap, super.key});
  final RouteHistory route;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final latest = route.latest, m = latest.metrics;
    final fastest = route.walks.length > 1 ? route.fastest : null;
    final usual = latest.counted ? route.usualKmh(except: latest) : null;
    final speeds = [
      for (final w in route.counted.toList().reversed) w.metrics.averageKmh!,
    ];
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(
                  painter: TracksPainter(
                    reference: route.route?.segments ?? const [],
                    tracks: [(latest.walk.segments, walkColor)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.l10n.routeLastWalked(
                        shortDate(context, route.lastWalked),
                        route.walks.length,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.latestPerformance(
                        kilometers(m.metres),
                        durationLabel(m.activeSeconds),
                        m.averageKmh == null ? '—' : speedLabel(m.averageKmh!),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (usual != null && m.averageKmh != null)
                      SpeedDifference(m.averageKmh! - usual, usual),
                    if (!latest.complete)
                      Text(
                        context.l10n.partialWalk(
                          (latest.coverage! * 100).round(),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (fastest != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            size: 16,
                            color: Color(0xff9a6b00),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              context.l10n.bestPerformance(
                                speedLabel(fastest.metrics.averageKmh!),
                                shortDate(context, fastest.walk.walk!.started),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    if (speeds.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          height: 22,
                          width: double.infinity,
                          child: CustomPaint(painter: Sparkline(speeds)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "▲ +0.2 km/h vs your usual 5.0 km/h": the arrow carries the direction, the
/// text stays in ink.
class SpeedDifference extends StatelessWidget {
  const SpeedDifference(this.difference, this.usual, {super.key});
  final double difference, usual;
  @override
  Widget build(BuildContext context) {
    final rounded = double.parse(difference.toStringAsFixed(1));
    return Row(
      children: [
        Icon(
          rounded > 0
              ? Icons.arrow_upward
              : rounded < 0
              ? Icons.arrow_downward
              : Icons.drag_handle,
          size: 15,
          color: rounded > 0
              ? forest
              : rounded < 0
              ? const Color(0xff9c4a12)
              : ink,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            context.l10n.speedVsUsual(
              '${signed(rounded)} km/h',
              speedLabel(usual),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Recorded lines over the faint route they belong to, fitted to the box.
class TracksPainter extends CustomPainter {
  TracksPainter({required this.reference, required this.tracks});
  final List<List<GeoPoint>> reference;
  final List<(List<List<GeoPoint>>, Color)> tracks;
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      ...reference.expand((s) => s),
      for (final (segments, _) in tracks) ...segments.expand((s) => s),
    ];
    if (points.isEmpty) return;
    final latScale = math.cos(points.first.lat * math.pi / 180);
    final xs = points.map((p) => p.lon * latScale),
        ys = points.map((p) => p.lat);
    final west = xs.reduce(math.min),
        east = xs.reduce(math.max),
        south = ys.reduce(math.min),
        north = ys.reduce(math.max);
    final scale = math.min(
      (size.width - 12) / math.max(east - west, .000001),
      (size.height - 12) / math.max(north - south, .000001),
    );
    Offset at(GeoPoint p) => Offset(
      size.width / 2 + (p.lon * latScale - (west + east) / 2) * scale,
      size.height / 2 - (p.lat - (south + north) / 2) * scale,
    );
    void draw(List<List<GeoPoint>> segments, Color color, double width) {
      final pen = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      // Each segment is drawn apart: gaps never become imaginary lines.
      for (final segment in segments) {
        if (segment.isEmpty) continue;
        final path = Path()..moveTo(at(segment.first).dx, at(segment.first).dy);
        for (final p in segment.skip(1)) {
          path.lineTo(at(p).dx, at(p).dy);
        }
        canvas.drawPath(path, pen);
      }
    }

    draw(reference, referenceColor, 2);
    for (final (segments, color) in tracks) {
      draw(segments, color, tracks.length > 1 ? 2.5 : 3);
    }
  }

  @override
  bool shouldRepaint(TracksPainter old) =>
      old.reference != reference || old.tracks != tracks;
}
