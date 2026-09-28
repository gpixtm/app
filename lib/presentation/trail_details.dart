import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/catalogue.dart';
import '../domain/models.dart';
import 'catalogue_view.dart';
import 'design.dart';
import 'join_departure.dart' show openDirectionsLink;
import 'localization.dart';

/// Name shown for a group: collections Gpix curates are translated, other
/// names are source or walker content and shown as they are.
String groupName(BuildContext context, TrailGroupSummary group) =>
    switch (group.editorial) {
      'st-james' => context.l10n.stJamesCollection,
      _ => group.name,
    };

String groupSubtitle(BuildContext context, TrailGroupSummary group) => [
  group.kind == TrailGroupKind.itinerary
      ? context.l10n.itinerary
      : context.l10n.collection,
  context.l10n.trailCount(group.trailCount),
  if (group.metres > 0) kilometers(group.metres),
].join(' · ');

String roleLabel(BuildContext context, MemberRole role, int? stage) =>
    switch (role) {
      MemberRole.stage => context.l10n.stageNumber(stage ?? 0),
      MemberRole.main => context.l10n.mainRoute,
      MemberRole.variant => context.l10n.variantRoute,
      MemberRole.link => context.l10n.linkRoute,
      MemberRole.excursion => context.l10n.excursionRoute,
      MemberRole.approach => context.l10n.approachRoute,
    };

/// What the source says about the open trail, in the trail panel: where it
/// belongs, its reference and waymarks, its description in the app language
/// when the source has one, its links and its licence.
class TrailDetailsSection extends StatefulWidget {
  const TrailDetailsSection(this.app, this.trail, {super.key});
  final AppController app;
  final Trail trail;
  @override
  State<TrailDetailsSection> createState() => _TrailDetailsSectionState();
}

class _TrailDetailsSectionState extends State<TrailDetailsSection> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.app.details;
    final description =
        details?.description(
          context.l10n.localeName,
          widget.trail.description,
        ) ??
        widget.trail.description;
    final fields = details?.fields ?? const {};
    final from = fields['from'], to = fields['to'];
    final muted = const TextStyle(fontSize: 12, color: mutedInk);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final path in details?.paths ?? const <TrailGroupPath>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    path.role == MemberRole.stage
                        ? context.l10n.stageOf(path.stage ?? 0)
                        : context.l10n.partOf,
                    style: muted,
                  ),
                  for (final group in path.groups)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        group.kind == TrailGroupKind.itinerary
                            ? Icons.route
                            : Icons.collections_bookmark_outlined,
                        size: 16,
                      ),
                      label: Text(groupName(context, group)),
                      onPressed: () => openGroup(context, widget.app, group.id),
                    ),
                ],
              ),
            ),
          if (details?.ref != null || details?.marking != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (details?.marking case final marking?) ...[
                    Semantics(
                      label: context.l10n.waymarks,
                      child: MarkingBadge(marking),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (details?.ref case final ref?)
                    Text(
                      ref,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (networkLabel(context, fields['network'])
                      case final network?) ...[
                    const SizedBox(width: 8),
                    Text(network, style: muted),
                  ],
                ],
              ),
            ),
          if (from != null && to != null)
            Text(context.l10n.fromTo(from, to), style: muted),
          if (details?.roundtrip == true)
            Text(context.l10n.loopTrail, style: muted),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: expanded ? null : 4,
              overflow: expanded ? null : TextOverflow.ellipsis,
            ),
            if (description.length > 180)
              TextButton(
                onPressed: () => setState(() => expanded = !expanded),
                child: Text(
                  expanded ? context.l10n.showLess : context.l10n.showMore,
                ),
              ),
          ],
          if (details?.hidden == true)
            Text(context.l10n.trailWithdrawn, style: muted),
          Wrap(
            spacing: 4,
            children: [
              if (fields['website'] case final website?)
                if (Uri.tryParse(website) case final uri?)
                  TextButton.icon(
                    onPressed: () => openDirectionsLink(context, uri),
                    icon: const Icon(Icons.public, size: 18),
                    label: Text(context.l10n.website),
                  ),
              if (wikipediaUri(fields['wikipedia']) case final uri?)
                TextButton.icon(
                  onPressed: () => openDirectionsLink(context, uri),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(context.l10n.wikipedia),
                ),
            ],
          ),
          if (details?.openData == true)
            Row(
              children: [
                Expanded(
                  child: Text(
                    details!.source == 'osm'
                        ? context.l10n.openStreetMapAttribution
                        : context.l10n.openDataAttribution(
                            details.attribution ?? details.source,
                          ),
                    style: muted,
                  ),
                ),
                if (details.osmId != null)
                  TextButton(
                    onPressed: () => openDirectionsLink(
                      context,
                      Uri.https(
                        'www.openstreetmap.org',
                        '/${details.osmType ?? 'relation'}/${details.osmId}',
                      ),
                    ),
                    child: Text(context.l10n.viewOnOpenStreetMap),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String? networkLabel(BuildContext context, String? network) =>
    switch (network) {
      'iwn' => context.l10n.internationalNetwork,
      'nwn' => context.l10n.nationalNetwork,
      'rwn' => context.l10n.regionalNetwork,
      'lwn' => context.l10n.localNetwork,
      _ => null,
    };

/// `fr:GR 20` → https://fr.wikipedia.org/wiki/GR_20
Uri? wikipediaUri(String? value) {
  final match = RegExp(r'^([a-z-]+):(.+)$').firstMatch(value ?? '');
  if (match == null) return null;
  return Uri.https(
    '${match[1]}.wikipedia.org',
    '/wiki/${match[2]!.replaceAll(' ', '_')}',
  );
}

/// Waymarks drawn from an OSM `osmc:symbol`: a background colour with a
/// foreground shape (bar, stripe, upper or lower half, dot…) and a short text,
/// such as the red and white stripes of a GR.
class MarkingBadge extends StatelessWidget {
  const MarkingBadge(this.symbol, {this.size = 28, super.key});
  final String symbol;
  final double size;
  @override
  Widget build(BuildContext context) {
    final parts = symbol.split(':');
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkingPainter(parts),
        child: parts.length > 4 && parts[parts.length - 2].isNotEmpty
            ? Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Text(
                      parts[parts.length - 2],
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color:
                            _markingColor(parts.last) ??
                            const Color(0xff000000),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

Color? _markingColor(String name) => switch (name.split('_').first) {
  'black' => const Color(0xff000000),
  'blue' => const Color(0xff1e5bc6),
  'brown' => const Color(0xff7a4b21),
  'gray' || 'grey' => const Color(0xff808080),
  'green' => const Color(0xff1d8a3a),
  'orange' => const Color(0xfff08a00),
  'purple' => const Color(0xff7b3fa0),
  'red' => const Color(0xffd21f1f),
  'white' => const Color(0xffffffff),
  'yellow' => const Color(0xfff5d20a),
  _ => null,
};

class _MarkingPainter extends CustomPainter {
  _MarkingPainter(this.parts);
  final List<String> parts;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = parts.length > 1 ? parts[1] : '';
    final round =
        background.endsWith('_round') || background.endsWith('_circle');
    final base = Paint()
      ..color = _markingColor(background) ?? const Color(0xffffffff);
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(round ? size.width / 2 : 4),
    );
    canvas.drawRRect(shape, base);
    canvas.save();
    canvas.clipRRect(shape);
    for (final foreground in [
      if (parts.length > 2) parts[2],
      if (parts.length > 5) parts[3],
    ]) {
      final split = foreground.indexOf('_');
      if (split < 0) continue;
      final color = _markingColor(foreground.substring(0, split));
      if (color == null) continue;
      final paint = Paint()..color = color;
      final w = size.width, h = size.height;
      switch (foreground.substring(split + 1)) {
        case 'bar':
          canvas.drawRect(Rect.fromLTWH(0, h * .35, w, h * .3), paint);
        case 'stripe':
          canvas.drawRect(Rect.fromLTWH(w * .35, 0, w * .3, h), paint);
        case 'upper':
          canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 2), paint);
        case 'lower':
          canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2), paint);
        case 'left':
          canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h), paint);
        case 'right':
          canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h), paint);
        case 'dot':
          canvas.drawCircle(rect.center, w * .28, paint);
        case 'circle':
          canvas.drawCircle(
            rect.center,
            w * .3,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * .12,
          );
        case 'frame':
          canvas.drawRect(
            rect.deflate(w * .12),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * .14,
          );
        case 'cross':
          canvas.drawRect(
            Rect.fromLTWH(w * .4, h * .12, w * .2, h * .76),
            paint,
          );
          canvas.drawRect(
            Rect.fromLTWH(w * .12, h * .4, w * .76, h * .2),
            paint,
          );
        case 'triangle':
          canvas.drawPath(
            Path()
              ..moveTo(w / 2, h * .15)
              ..lineTo(w * .85, h * .82)
              ..lineTo(w * .15, h * .82)
              ..close(),
            paint,
          );
        case 'diamond':
          canvas.drawPath(
            Path()
              ..moveTo(w / 2, h * .12)
              ..lineTo(w * .88, h / 2)
              ..lineTo(w / 2, h * .88)
              ..lineTo(w * .12, h / 2)
              ..close(),
            paint,
          );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55000000),
    );
  }

  @override
  bool shouldRepaint(_MarkingPainter old) => old.parts.join() != parts.join();
}

/// Offline and group actions of a trail in the panel: a catalogue trail can
/// be made available offline (it is automatically when walked), a trail made
/// available offline can be removed from the phone, and any shared trail can
/// join one of the walker's groups.
class TrailKeepActions extends StatelessWidget {
  const TrailKeepActions(this.app, this.trail, {super.key});
  final AppController app;
  final Trail trail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!app.stored(trail))
          OutlinedButton.icon(
            onPressed: app.busy ? null : () => app.makeAvailableOffline(trail),
            icon: const Icon(Icons.download_for_offline_outlined),
            label: Text(context.l10n.makeAvailableOffline),
          )
        else if (app.isOfflineCopy(trail))
          Row(
            children: [
              const Icon(Icons.offline_pin, color: forest, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(context.l10n.availableOfflineLabel)),
              TextButton(
                onPressed:
                    app.busy ||
                        (app.session?.active == true &&
                            app.selected?.id == trail.id)
                    ? null
                    : () => app.removeOffline(trail),
                child: Text(context.l10n.removeFromPhone),
              ),
            ],
          ),
        if (app.collaborative?.catalogue != null)
          OutlinedButton.icon(
            onPressed: app.busy ? null : () => addToGroup(context, app, trail),
            icon: const Icon(Icons.playlist_add),
            label: Text(context.l10n.addToGroup),
          ),
      ],
    ),
  );
}
