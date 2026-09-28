import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/walk_metrics.dart';
import 'catalogue_view.dart' show TrailColourLegend;
import 'design.dart';
import 'localization.dart';
import 'pin_images.dart';
import 'trail_reviews.dart';

/// Every trail pinned on screen, listed under the map, nearest to the centre
/// first, as on AllTrails. Lowered, only its title bar remains and the map is
/// free; raised, it pages through the trails 30 at a time.
class VisibleTrailsSheet extends StatefulWidget {
  const VisibleTrailsSheet(
    this.app,
    this.trails, {
    required this.onOpen,
    required this.importTrails,
    super.key,
  });
  final AppController app;
  final List<Trail> trails;
  final void Function(Trail) onOpen;
  final VoidCallback importTrails;
  @override
  State<VisibleTrailsSheet> createState() => _VisibleTrailsSheetState();
}

class _VisibleTrailsSheetState extends State<VisibleTrailsSheet> {
  static const page = 30;
  final sheet = DraggableScrollableController();
  int shown = page;

  /// Share of the screen the lowered bar takes.
  double collapsed = .13;
  AppController get app => widget.app;

  @override
  void didUpdateWidget(VisibleTrailsSheet old) {
    super.didUpdateWidget(old);
    // A new view starts again from its nearest trails.
    if (!identical(old.trails, widget.trails)) shown = page;
  }

  @override
  void dispose() {
    sheet.dispose();
    super.dispose();
  }

  void toggle() {
    if (!sheet.isAttached) return;
    sheet.animateTo(
      sheet.size > .3 ? collapsed : .5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trails = widget.trails;
    final count = shown.clamp(0, trails.length);
    // Lowered, the bar keeps its title (and the import action on a first
    // visit) whatever the screen height.
    final height = MediaQuery.sizeOf(context).height;
    collapsed = ((app.trails.isEmpty ? 150 : 104) / height).clamp(.1, .3);
    return DraggableScrollableSheet(
      key: const ValueKey('in-view'),
      controller: sheet,
      initialChildSize: collapsed,
      minChildSize: collapsed,
      maxChildSize: .88,
      snap: true,
      snapSizes: [collapsed, .5, .88],
      builder: (context, scroll) => Material(
        color: Colors.white,
        elevation: 8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 500 && shown < trails.length) {
              setState(() => shown += page);
            }
            return false;
          },
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: count + 2,
            itemBuilder: (context, index) {
              if (index == 0) return header(context);
              if (index == count + 1) return footer(context);
              final trail = trails[index - 1];
              return VisibleTrailTile(
                app,
                trail,
                onTap: () => widget.onOpen(trail),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget header(BuildContext context) => InkWell(
    onTap: toggle,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.trails.isEmpty
                      ? context.l10n.noTrailsInView
                      : context.l10n.trailsInView(widget.trails.length),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (app.trails.isNotEmpty)
                IconButton(
                  tooltip: context.l10n.importGpx,
                  onPressed: app.busy ? null : widget.importTrails,
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              if (app.recorder != null)
                IconButton(
                  tooltip: context.l10n.startRoute,
                  onPressed: app.busy ? null : app.freeWalk,
                  icon: const Icon(Icons.route),
                ),
            ],
          ),
          // A first visit shows the action plainly, even with the list lowered.
          if (app.trails.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: app.busy ? null : widget.importTrails,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.importGpx),
                ),
              ),
            ),
          const TrailColourLegend(),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );

  Widget footer(BuildContext context) {
    final muted = const TextStyle(fontSize: 12, color: Color(0xff627068));
    if (widget.trails.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.moveMapForTrails),
            if (app.trails.isEmpty) ...[
              const SizedBox(height: 12),
              Text(context.l10n.mapAroundYou, style: muted),
            ],
          ],
        ),
      );
    }
    if (shown < widget.trails.length) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Text(
        app.areaTruncated
            ? context.l10n.zoomInForMoreTrails
            : context.l10n.allTrailsInViewListed,
        style: muted,
      ),
    );
  }
}

/// One trail of the list: its pin, name, length, climb, reference and rating.
class VisibleTrailTile extends StatelessWidget {
  const VisibleTrailTile(
    this.app,
    this.trail, {
    required this.onTap,
    super.key,
  });
  final AppController app;
  final Trail trail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final own = app.stored(trail);
    final summary = app.sharedFor(trail);
    final metrics = own ? WalkMetrics(trail) : null;
    final details = [
      shortKilometers(summary?.metres ?? metrics?.metres ?? 0),
      if (metrics != null && metrics.maximumAltitude != null)
        context.l10n.ascentShort(metrics.ascent.round()),
      ?summary?.ref,
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: TrailPinBadge(catalogue: !own),
      title: Text(
        trail.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(details.join(' · ')),
          if (summary != null && summary.reviews > 0)
            RatingSummary(count: summary.reviews, average: summary.average),
          if (own)
            Text(
              app.isOfflineCopy(trail)
                  ? context.l10n.offlineTag
                  : context.l10n.myTrailTag,
              style: const TextStyle(
                color: forest,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
