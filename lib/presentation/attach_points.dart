import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/point_attachment.dart';
import 'design.dart';
import 'localization.dart';

/// Colours of the points previewed while attaching, on the map and in the
/// panel's legend.
const attachAddedHex = '#1f7a4d';
const attachKnownHex = '#2563eb';
const attachLeftHex = '#9aa19d';

String attachHex(PointFate fate) => switch (fate) {
  PointFate.added => attachAddedHex,
  PointFate.known => attachKnownHex,
  PointFate.tooFar || PointFate.unnamed => attachLeftHex,
};

Color _color(String hex) =>
    Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));

/// Panel over the map previewing points files attached to a trail: what
/// becomes a place, what the trail already has, what stays in the file.
/// Nothing is shared before the walker confirms they may share the points.
class AttachPointsPanel extends StatefulWidget {
  const AttachPointsPanel(
    this.app, {
    required this.scroll,
    required this.handle,
    super.key,
  });
  final AppController app;
  final ScrollController scroll;
  final Widget handle;
  @override
  State<AttachPointsPanel> createState() => _AttachPointsPanelState();
}

class _AttachPointsPanelState extends State<AttachPointsPanel> {
  bool confirmed = false;
  AppController get app => widget.app;

  Widget legend(String hex, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: _color(hex),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 1)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = app.attaching!;
    final added = plan.count(PointFate.added);
    final known = plan.count(PointFate.known);
    final tooFar = plan.count(PointFate.tooFar);
    final unnamed = plan.count(PointFate.unnamed);
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        widget.handle,
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.attachPointsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: l10n.cancel,
              onPressed: app.busy ? null : app.cancelAttachment,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(
          l10n.attachPointsFrom(
            plan.points.length,
            plan.sources.map((s) => s.name).join(', '),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.route, color: forest),
          title: Text(
            l10n.attachPointsTo(plan.targets.map((t) => t.name).join(', ')),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: app.attachTargets.isEmpty
              ? null
              : TextButton(
                  onPressed: app.busy
                      ? null
                      : () => chooseAttachTarget(context, app),
                  child: Text(l10n.changeTrail),
                ),
        ),
        legend(attachAddedHex, l10n.attachAdded(added)),
        if (known > 0) legend(attachKnownHex, l10n.attachKnown(known)),
        if (tooFar > 0) legend(attachLeftHex, l10n.attachTooFar(tooFar)),
        if (unnamed > 0) legend(attachLeftHex, l10n.attachUnnamed(unnamed)),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: confirmed,
          onChanged: (value) => setState(() => confirmed = value ?? false),
          title: Text(
            l10n.attachShareConfirm,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: confirmed && plan.attachesAny && !app.busy
              ? app.confirmAttachment
              : null,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(l10n.attach),
        ),
        TextButton(
          onPressed: app.busy ? null : app.cancelAttachment,
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// The trails the points may go to, most points within reach first.
Future<void> chooseAttachTarget(BuildContext context, AppController app) {
  final total = app.attaching?.points.length ?? 0;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      maxChildSize: .9,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              sheet.l10n.chooseAttachTrail,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
          ),
          for (final (index, target) in app.attachTargets.indexed)
            ListTile(
              leading: Icon(
                Icons.route,
                color: target.catalogue ? catalogueColor : forest,
              ),
              title: Text(target.trail.name),
              subtitle: Text(
                [
                  sheet.l10n.pointsWithinReach(target.inRange, total),
                  if (target.catalogue) sheet.l10n.catalogueTrailChoice,
                ].join(' · '),
              ),
              trailing: index == 0
                  ? StatusPill(sheet.l10n.recommendedTrail, good: true)
                  : null,
              selected:
                  app.attaching?.targets.any(
                    (t) => t.sharedId == target.trail.sharedId,
                  ) ==
                  true,
              onTap: () {
                Navigator.pop(sheet);
                app.chooseAttachTarget(target);
              },
            ),
        ],
      ),
    ),
  );
}

/// Add points to [trail]: from a GPX file on the phone, or a points file of
/// the library. Returns whether attaching started, to show it on the map.
Future<bool> addPointsTo(
  BuildContext context,
  AppController app,
  Trail trail, {
  required Future<void> Function(Trail attachTo) importFromPhone,
}) async {
  final choice = await showModalBottomSheet<Trail?>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            sheet.l10n.addPoints,
            style: Theme.of(sheet).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined, color: forest),
          title: Text(sheet.l10n.addPointsFromPhone),
          onTap: () => Navigator.pop(sheet, trail),
        ),
        if (app.pointsFiles.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              sheet.l10n.addPointsFromLibrary,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final file in app.pointsFiles)
            ListTile(
              leading: const Icon(Icons.place_outlined, color: forest),
              title: Text(file.name),
              subtitle: Text(sheet.l10n.pointCount(file.pois.length)),
              onTap: () => Navigator.pop(sheet, file),
            ),
        ],
      ],
    ),
  );
  if (choice == null) return false;
  if (identical(choice, trail)) {
    await importFromPhone(trail);
  } else {
    await app.beginAttachment([choice], targets: [trail]);
  }
  return app.attaching != null;
}
