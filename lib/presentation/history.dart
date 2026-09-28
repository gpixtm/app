import 'localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/walk_metrics.dart';
import 'design.dart';
import 'walk_controls.dart';
import 'walk_stats.dart';

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
  AppController get app => widget.app;

  void details(Trail walk) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .94,
        builder: (_, scroll) => StreamBuilder<void>(
          stream: app.changes.stream,
          builder: (_, _) {
            final current =
                app.history.where((t) => t.id == walk.id).firstOrNull ?? walk;
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              children: [
                Text(
                  current.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(dateLabel(current.walk!.started)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: CustomPaint(painter: WalkThumbnail(current)),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    app.viewHistory(walk: current);
                    widget.openMap();
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(context.l10n.viewOnMap),
                ),
                const SizedBox(height: 16),
                WalkStats(current),
                OutlinedButton.icon(
                  onPressed: app.busy || app.health == null
                      ? null
                      : () => app.importHealth(current),
                  icon: const Icon(Icons.watch_outlined),
                  label: Text(context.l10n.importWatchData),
                ),
                if (app.message != null) Text(context.message(app.message!)),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.openSettings();
                  },
                  child: Text(context.l10n.watchSettings),
                ),
                TextButton(
                  onPressed: app.busy
                      ? null
                      : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text(context.l10n.deleteWalkQuestion),
                              content: Text(context.l10n.deleteWalkInfo),
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
                          if (yes == true) {
                            await app.removeTrail(current);
                            if (mounted && context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                  child: Text(context.l10n.deleteWalk),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = app.recorder?.current;
    final items = app.history
        .where(
          (t) =>
              filter == 0 ||
              (filter == 1
                  ? t.walk!.sourceTrailId != null
                  : t.walk!.sourceTrailId == null),
        )
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
          context.l10n.walkCountDistance(
            app.history.length,
            kilometers(
              app.history.fold<double>(
                0,
                (sum, t) => sum + WalkMetrics(t).metres,
              ),
            ),
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
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(context.l10n.noWalks),
          ),
        for (final walk in items)
          Card(
            child: InkWell(
              onTap: () => details(walk),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel(walk.walk!.started),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      walk.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      height: 90,
                      child: CustomPaint(
                        size: const Size(double.infinity, 90),
                        painter: WalkThumbnail(walk),
                      ),
                    ),
                    Text(
                      '${kilometers(WalkMetrics(walk).metres)} · ${durationLabel(walk.walk!.seconds)} · ${walk.walk!.sourceTrailId == null ? context.l10n.freeWalk : context.l10n.withGpx}',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class WalkThumbnail extends CustomPainter {
  WalkThumbnail(this.walk);
  final Trail walk;
  @override
  void paint(Canvas canvas, Size size) {
    final points = walk.points.toList();
    if (points.isEmpty) return;
    final latScale = math.cos(points.first.lat * math.pi / 180);
    final xs = points.map((p) => p.lon * latScale),
        ys = points.map((p) => p.lat);
    final west = xs.reduce(math.min),
        east = xs.reduce(math.max),
        south = ys.reduce(math.min),
        north = ys.reduce(math.max);
    final scale = math.min(
      (size.width - 24) / math.max(east - west, .000001),
      (size.height - 24) / math.max(north - south, .000001),
    );
    final paint = Paint()
      ..color = const Color(0xffc66a25)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final segment in walk.segments) {
      final path = Path();
      for (var i = 0; i < segment.length; i++) {
        final p = segment[i],
            x =
                size.width / 2 +
                (segment[i].lon * latScale - (west + east) / 2) * scale;
        final y = size.height / 2 - (p.lat - (south + north) / 2) * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WalkThumbnail old) => old.walk != walk;
}
