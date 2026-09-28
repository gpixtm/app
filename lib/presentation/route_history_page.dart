import 'localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/route_history.dart';
import '../domain/trail_geometry.dart';
import '../domain/walk_metrics.dart';
import 'design.dart';
import 'history.dart';
import 'history_charts.dart';
import 'walk_stats.dart';

enum _Mode { walk, compare, progress }

/// Every walk of one route: switch between walks, compare two of them along
/// the route, and follow the progress over time.
class RouteHistoryPage extends StatefulWidget {
  const RouteHistoryPage(
    this.app, {
    required this.routeId,
    required this.measures,
    required this.openMap,
    required this.openSettings,
    super.key,
  });
  final AppController app;
  final String routeId;
  final RouteMeasures measures;
  final VoidCallback openMap, openSettings;
  @override
  State<RouteHistoryPage> createState() => _RouteHistoryPageState();
}

class _RouteHistoryPageState extends State<RouteHistoryPage> {
  AppController get app => widget.app;
  _Mode mode = _Mode.walk;
  String? selectedId, aId, bId;
  int? cursor;

  RouteHistory? _group;
  Object? _walks, _library;

  /// Measured again only when the history or the library changed.
  RouteHistory? get group {
    if (!identical(_walks, app.history) || !identical(_library, app.trails)) {
      _walks = app.history;
      _library = app.trails;
      final walks = app.history.where(
        (t) => (t.walk!.statisticsTrailId ?? t.id) == widget.routeId,
      );
      _group = groupWalks(
        walks,
        app.trails,
        measures: widget.measures,
      ).firstOrNull;
    }
    return _group;
  }

  WalkOnRoute _find(RouteHistory g, String? id) =>
      g.walks.where((w) => w.walk.id == id).firstOrNull ?? g.latest;

  void select(String id) => setState(() => selectedId = id);

  void showOnMap(WalkOnRoute walk) {
    app.viewHistory(walk: walk.walk);
    Navigator.of(context).pop();
    widget.openMap();
  }

  /// The route on the phone to walk on along, unless a walk is recording.
  Trail? _continuable(RouteHistory g) => app.recorder?.current != null
      ? null
      : app.trails.where((t) => t.id == g.id && t.followable).firstOrNull;

  /// Go on the next day from where the walker stands, in the direction of
  /// the last walk on this route.
  void continueRoute(RouteHistory g, Trail route) {
    Navigator.of(context).pop();
    widget.openMap();
    unawaited(app.continueRoute(route, reversed: g.latest.reversed));
  }

  Future<void> deleteAll(RouteHistory g) async {
    final finished = g.walks.where((w) => w.finished).map((w) => w.walk);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteAllWalksQuestion(finished.length)),
        content: Text(context.l10n.deleteAllWalksInfo),
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
    if (yes == true) await app.removeWalks(finished.toList());
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: app.changes.stream,
    builder: (context, _) {
      final g = group;
      if (g == null) {
        // Every walk of the route was deleted.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
        return const Scaffold();
      }
      final current = _find(g, selectedId);
      final many = g.walks.length > 1;
      final m = many ? mode : _Mode.walk;
      final (a, b) = _pair(g);
      return Scaffold(
        appBar: AppBar(
          title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<int>(
              onSelected: (_) => deleteAll(g),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 0,
                  enabled: !app.busy && g.walks.any((w) => w.finished),
                  child: Text(context.l10n.deleteAllWalks),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
          children: [
            Text(
              '${context.l10n.walkCountDistance(g.walks.length, kilometers(g.metres))} · ${context.l10n.routeSince(shortDate(context, g.firstWalked))}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Card(
              child: SizedBox(
                height: 190,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: CustomPaint(
                    painter: TracksPainter(
                      reference: g.route?.segments ?? const [],
                      tracks: m == _Mode.compare && a != b
                          ? [
                              (b.walk.segments, otherWalkColor),
                              (a.walk.segments, walkColor),
                            ]
                          : [(current.walk.segments, walkColor)],
                    ),
                  ),
                ),
              ),
            ),
            if (many) ...[
              const SizedBox(height: 12),
              SegmentedButton<_Mode>(
                segments: [
                  ButtonSegment(
                    value: _Mode.walk,
                    label: Text(context.l10n.walkTab),
                  ),
                  ButtonSegment(
                    value: _Mode.compare,
                    label: Text(context.l10n.compareTab),
                  ),
                  ButtonSegment(
                    value: _Mode.progress,
                    label: Text(context.l10n.progressTab),
                  ),
                ],
                selected: {m},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => mode = v.single),
              ),
            ],
            const SizedBox(height: 12),
            ...switch (m) {
              _Mode.walk => _walk(g, current),
              _Mode.compare => _compare(g, a, b),
              _Mode.progress => _progress(g),
            },
          ],
        ),
      );
    },
  );

  // ---- One walk ----------------------------------------------------------

  List<Widget> _walk(RouteHistory g, WalkOnRoute current) {
    final index = g.walks.indexOf(current);
    final older = index + 1 < g.walks.length ? g.walks[index + 1] : null;
    final newer = index > 0 ? g.walks[index - 1] : null;
    final details = current.walk.walk!;
    final kmh = current.metrics.averageKmh;
    final usual = current.counted ? g.usualKmh(except: current) : null;
    return [
      if (g.walks.length > 1) ...[
        _WalkStrip(g, selected: current, onSelect: (w) => select(w.walk.id)),
        const SizedBox(height: 8),
      ],
      // Swiping the walk moves to the previous or next walk, like a gallery.
      GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300 && newer != null) select(newer.walk.id);
          if (v > 300 && older != null) select(older.walk.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n.previousWalk,
                  onPressed: older == null ? null : () => select(older.walk.id),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (current.walk.name != g.name)
                        Text(
                          current.walk.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        dateLabel(details.started),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.nextWalk,
                  onPressed: newer == null ? null : () => select(newer.walk.id),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Wrap(spacing: 6, runSpacing: 6, children: _badges(g, current)),
            if (usual != null && kmh != null) ...[
              const SizedBox(height: 8),
              SpeedDifference(kmh - usual, usual),
            ],
            if (!current.complete) ...[
              const SizedBox(height: 6),
              Text(
                context.l10n.partialWalkInfo,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => showOnMap(current),
        icon: const Icon(Icons.map_outlined),
        label: Text(context.l10n.viewOnMap),
      ),
      if (_continuable(g) case final route?) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: app.busy ? null : () => continueRoute(g, route),
          icon: const Icon(Icons.directions_walk),
          label: Text(context.l10n.continueRoute),
        ),
        Text(
          context.l10n.continueRouteInfo,
          style: const TextStyle(fontSize: 12, color: mutedInk),
        ),
      ],
      const SizedBox(height: 16),
      WalkStats(current.walk),
      OutlinedButton.icon(
        onPressed: app.busy || app.health == null
            ? null
            : () => app.importHealth(current.walk),
        icon: const Icon(Icons.watch_outlined),
        label: Text(context.l10n.importWatchData),
      ),
      if (current.finished)
        OutlinedButton.icon(
          onPressed: app.busy || app.health == null
              ? null
              : () => app.shareToHealth(current.walk),
          icon: const Icon(Icons.ios_share),
          label: Text(context.l10n.shareToHealth),
        ),
      if (app.message != null) Text(context.message(app.message!)),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.openSettings();
        },
        child: Text(context.l10n.watchSettings),
      ),
      TextButton(
        onPressed: app.busy ? null : () => _deleteOne(g, current),
        child: Text(context.l10n.deleteWalk),
      ),
    ];
  }

  Future<void> _deleteOne(RouteHistory g, WalkOnRoute walk) async {
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
    if (yes != true) return;
    // The neighbouring walk stays in view once this one is gone.
    final index = g.walks.indexOf(walk);
    final next = index + 1 < g.walks.length
        ? g.walks[index + 1]
        : index > 0
        ? g.walks[index - 1]
        : null;
    if (next != null) setState(() => selectedId = next.walk.id);
    await app.removeTrail(walk.walk);
  }

  List<Widget> _badges(RouteHistory g, WalkOnRoute walk) {
    final l10n = context.l10n;
    final many = g.walks.length > 1;
    return [
      if (!walk.finished)
        _Badge(Icons.fiber_manual_record, l10n.walkInProgress),
      if (!walk.complete)
        _Badge(
          Icons.incomplete_circle,
          l10n.partialWalk((walk.coverage! * 100).round()),
        ),
      if (walk.reversed) _Badge(Icons.swap_horiz, l10n.walkReversed),
      if (many && identical(g.fastest, walk))
        _Badge(Icons.emoji_events_outlined, l10n.recordFastest),
      if (many && identical(g.longest, walk))
        _Badge(Icons.emoji_events_outlined, l10n.recordLongest),
      if (many && identical(g.highest, walk))
        _Badge(Icons.emoji_events_outlined, l10n.recordHighest),
    ];
  }

  // ---- Two walks ---------------------------------------------------------

  /// A defaults to the latest complete walk, B to the record, or else the
  /// latest other complete walk, or else any other walk.
  (WalkOnRoute, WalkOnRoute) _pair(RouteHistory g) {
    final a = aId == null ? g.counted.firstOrNull ?? g.latest : _find(g, aId);
    final record = g.fastest;
    final fallback = record != null && !identical(record, a)
        ? record
        : g.counted.where((w) => !identical(w, a)).firstOrNull ??
              g.walks.firstWhere((w) => !identical(w, a), orElse: () => a);
    final b = bId == null ? fallback : _find(g, bId);
    return (a, b);
  }

  List<Widget> _compare(RouteHistory g, WalkOnRoute a, WalkOnRoute b) {
    final l10n = context.l10n;
    final gap = identical(a, b)
        ? const <(double, double)>[]
        : progressGap(a, b);
    final profile = g.route == null
        ? const <ProfilePoint>[]
        : TrailGeometry(g.route!).orientedProfile(a.reversed);
    return [
      _WalkPicker(
        label: l10n.walkA,
        color: walkColor,
        route: g,
        value: a,
        onChanged: (w) => setState(() {
          aId = w.walk.id;
          cursor = null;
        }),
      ),
      const SizedBox(height: 8),
      _WalkPicker(
        label: l10n.walkB,
        color: otherWalkColor,
        route: g,
        value: b,
        onChanged: (w) => setState(() {
          bId = w.walk.id;
          cursor = null;
        }),
      ),
      const SizedBox(height: 16),
      if (identical(a, b))
        Text(l10n.pickTwoWalks)
      else ...[
        _ComparisonTable(a, b),
        const SizedBox(height: 20),
        Text(
          l10n.aheadBehindTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        if (a.reversed != b.reversed)
          Text(l10n.gapOppositeDirections)
        else if (gap.isEmpty)
          Text(l10n.gapUnavailable)
        else ...[
          _gapCaption(
            gap[cursor != null && cursor! < gap.length
                ? cursor!
                : gap.length - 1],
          ),
          const SizedBox(height: 6),
          GapChart(
            gap: gap,
            profile: profile,
            aheadColor: walkColor,
            behindColor: otherWalkColor,
            minutes: (v) => l10n.signedMinutes(signed(v, 0)),
            distance: kilometers,
            onCursor: (i) => setState(() => cursor = i),
          ),
          const SizedBox(height: 6),
          Text(l10n.aheadBehindInfo, style: const TextStyle(fontSize: 12)),
        ],
      ],
    ];
  }

  Widget _gapCaption((double, double) point) {
    final l10n = context.l10n;
    final (along, seconds) = point;
    final whole = seconds.abs().round();
    final time = l10n.minutesSeconds(whole ~/ 60, whole % 60);
    final at = kilometers(along);
    return Text(
      whole == 0
          ? l10n.gapLevel(at)
          : seconds > 0
          ? l10n.gapAhead(at, time)
          : l10n.gapBehind(at, time),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  // ---- Over time ---------------------------------------------------------

  List<Widget> _progress(RouteHistory g) {
    final l10n = context.l10n;
    final counted = g.counted.toList().reversed.toList();
    final usual = g.usualKmh();
    final selected = counted.indexWhere((w) => w.walk.id == selectedId);
    final records = [
      (
        l10n.recordFastest,
        g.fastest,
        (WalkMetrics m) => speedLabel(m.averageKmh!),
      ),
      (l10n.recordLongest, g.longest, (WalkMetrics m) => kilometers(m.metres)),
      (
        l10n.recordHighest,
        g.highest,
        (WalkMetrics m) => '+${m.ascent.round()} m',
      ),
    ];
    return [
      Text(
        l10n.speedProgressTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      if (counted.length < 2)
        Text(l10n.progressNeedsTwo)
      else ...[
        if (selected >= 0)
          Text(
            l10n.speedOnDate(
              shortDate(context, counted[selected].walk.walk!.started),
              speedLabel(counted[selected].metrics.averageKmh!),
            ),
          ),
        SpeedChart(
          walks: [
            for (final w in counted)
              (w.walk.walk!.started, w.metrics.averageKmh!),
          ],
          usual: usual,
          selected: selected < 0 ? null : selected,
          speed: (v) => decimal(v),
          onSelect: (i) => select(counted[i].walk.id),
        ),
        Text(l10n.speedProgressInfo, style: const TextStyle(fontSize: 12)),
      ],
      const SizedBox(height: 20),
      Text(l10n.records, style: const TextStyle(fontWeight: FontWeight.w700)),
      for (final (title, walk, value) in records)
        if (walk != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(title),
            subtitle: Text(
              '${value(walk.metrics)} · ${shortDate(context, walk.walk.walk!.started)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() {
              selectedId = walk.walk.id;
              mode = _Mode.walk;
            }),
          ),
      const SizedBox(height: 12),
      _Figures({
        l10n.distanceWalked: kilometers(g.metres),
        l10n.totalActiveTime: durationLabel(g.activeSeconds),
        l10n.usualSpeed: usual == null ? '—' : speedLabel(usual),
      }),
    ];
  }
}

/// Every walk of the route, oldest on the left and the latest in view.
class _WalkStrip extends StatelessWidget {
  const _WalkStrip(
    this.route, {
    required this.selected,
    required this.onSelect,
  });
  final RouteHistory route;
  final WalkOnRoute selected;
  final ValueChanged<WalkOnRoute> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      reverse: true,
      itemCount: route.walks.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final w = route.walks[i], chosen = identical(w, selected);
        final record = identical(route.fastest, w);
        return ChoiceChip(
          selected: chosen,
          showCheckmark: false,
          onSelected: (_) => onSelect(w),
          avatar: record
              ? const Icon(Icons.emoji_events_outlined, size: 16)
              : !w.complete
              ? const Icon(Icons.incomplete_circle, size: 16)
              : null,
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shortDate(context, w.walk.walk!.started),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                w.metrics.averageKmh == null
                    ? kilometers(w.metrics.metres)
                    : speedLabel(w.metrics.averageKmh!),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class _WalkPicker extends StatelessWidget {
  const _WalkPicker({
    required this.label,
    required this.color,
    required this.route,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final Color color;
  final RouteHistory route;
  final WalkOnRoute value;
  final ValueChanged<WalkOnRoute> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value.walk.id,
    key: ValueKey('$label-${value.walk.id}'),
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(Icons.circle, color: color, size: 16),
    ),
    items: [
      for (final w in route.walks)
        DropdownMenuItem(
          value: w.walk.id,
          child: Text(
            [
              DateFormat.yMMMd(context.l10n.localeName)
                  .format(w.walk.walk!.started.toLocal()),
              if (w.metrics.averageKmh != null)
                speedLabel(w.metrics.averageKmh!),
              if (!w.complete)
                context.l10n.partialWalk((w.coverage! * 100).round()),
              if (w.reversed) context.l10n.walkReversed,
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (id) {
      final w = route.walks.where((w) => w.walk.id == id).firstOrNull;
      if (w != null) onChanged(w);
    },
  );
}

/// The two walks side by side; the difference is A minus B.
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable(this.a, this.b);
  final WalkOnRoute a, b;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ma = a.metrics, mb = b.metrics;
    final ha = a.walk.walk!, hb = b.walk.walk!;
    String pace(double? s) {
      if (s == null) return '—';
      final r = s.round();
      return '${r ~/ 60}:${(r % 60).toString().padLeft(2, '0')}';
    }

    String minutes(int seconds) {
      final m = (seconds.abs() / 60).round();
      return '${seconds < 0
          ? '−'
          : seconds > 0
          ? '+'
          : ''}${durationLabel(m * 60)}';
    }

    final rows = <(String, String, String, String)>[
      (
        l10n.distanceWalked,
        kilometers(ma.metres),
        kilometers(mb.metres),
        '${signed(_tenths(ma.metres / 1000) - _tenths(mb.metres / 1000))} km',
      ),
      (
        l10n.activeDuration,
        durationLabel(ma.activeSeconds),
        durationLabel(mb.activeSeconds),
        minutes(ma.activeSeconds - mb.activeSeconds),
      ),
      (
        l10n.averageSpeed,
        ma.averageKmh == null ? '—' : decimal(ma.averageKmh!),
        mb.averageKmh == null ? '—' : decimal(mb.averageKmh!),
        ma.averageKmh == null || mb.averageKmh == null
            ? '—'
            : signed(_tenths(ma.averageKmh!) - _tenths(mb.averageKmh!)),
      ),
      (
        l10n.averagePace,
        pace(ma.paceSeconds),
        pace(mb.paceSeconds),
        ma.paceSeconds == null || mb.paceSeconds == null
            ? '—'
            : '${ma.paceSeconds! < mb.paceSeconds! ? '−' : '+'}${pace((ma.paceSeconds! - mb.paceSeconds!).abs())}',
      ),
      if (ma.hasElevation || mb.hasElevation)
        (
          l10n.ascent,
          ma.hasElevation ? '+${ma.ascent.round()} m' : '—',
          mb.hasElevation ? '+${mb.ascent.round()} m' : '—',
          ma.hasElevation && mb.hasElevation
              ? '${signed(ma.ascent - mb.ascent, 0)} m'
              : '—',
        ),
      if (ha.bestSteps != null || hb.bestSteps != null)
        (
          l10n.steps,
          _count(context, ha.bestSteps),
          _count(context, hb.bestSteps),
          ha.bestSteps == null || hb.bestSteps == null
              ? '—'
              : signed(ha.bestSteps! - hb.bestSteps!, 0),
        ),
      if (ha.bestCalories != null || hb.bestCalories != null)
        (
          l10n.activeCalories,
          ha.bestCalories == null ? '—' : '${ha.bestCalories!.round()}',
          hb.bestCalories == null ? '—' : '${hb.bestCalories!.round()}',
          ha.bestCalories == null || hb.bestCalories == null
              ? '—'
              : signed(ha.bestCalories! - hb.bestCalories!, 0),
        ),
      if (ha.health?.averageHeartRate != null ||
          hb.health?.averageHeartRate != null)
        (
          l10n.averageHeartRate,
          _count(context, ha.health?.averageHeartRate?.round()),
          _count(context, hb.health?.averageHeartRate?.round()),
          ha.health?.averageHeartRate == null ||
                  hb.health?.averageHeartRate == null
              ? '—'
              : signed(
                  ha.health!.averageHeartRate! - hb.health!.averageHeartRate!,
                  0,
                ),
        ),
    ];
    Widget cell(String text, {bool bold = false, Color? dot}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Icon(Icons.circle, size: 10, color: dot),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: Color(0xffdfe5dc)),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox(),
            cell(l10n.walkALetter, bold: true, dot: walkColor),
            cell(l10n.walkBLetter, bold: true, dot: otherWalkColor),
            cell(l10n.difference, bold: true),
          ],
        ),
        for (final (label, va, vb, diff) in rows)
          TableRow(
            children: [
              cell(label),
              cell(va, bold: true),
              cell(vb, bold: true),
              cell(diff),
            ],
          ),
      ],
    );
  }

  /// Differences are taken between the values shown, so they add up.
  static double _tenths(double value) => (value * 10).round() / 10;

  static String _count(BuildContext context, num? value) => value == null
      ? '—'
      : NumberFormat.decimalPattern(context.l10n.localeName).format(value);
}

class _Figures extends StatelessWidget {
  const _Figures(this.values);
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final MapEntry(:key, :value) in values.entries)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfff0f3ed),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(key, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
    ],
  );
}
