import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/shared_trails.dart';
import 'design.dart';
import 'localization.dart';

/// Name and optional comment of a place; returns them, or null when cancelled.
class PlaceDialog extends StatefulWidget {
  const PlaceDialog({this.current, super.key});
  final TrailPlace? current;
  @override
  State<PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<PlaceDialog> {
  late final name = TextEditingController(text: widget.current?.name);
  late final comment = TextEditingController(text: widget.current?.comment);
  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.current == null ? l10n.newPlaceTitle : l10n.editPlaceTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.current == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.placeAtPosition),
              ),
            TextField(
              controller: name,
              autofocus: true,
              maxLength: maximumPlaceNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.placeName),
            ),
            TextField(
              controller: comment,
              maxLength: maximumReviewLength,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.reviewComment),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            minimumSize: const Size(48, 44),
          ),
          onPressed: name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (name.text, comment.text)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Ask for a name and comment, then add the place where the walker stands.
Future<void> addPlaceHere(
  BuildContext context,
  AppController app,
  Trail trail,
) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (_) => const PlaceDialog(),
  );
  if (result case (final name, final comment)) {
    await app.addPlace(trail, name, comment);
  }
}

/// Details of a place touched on the map; its author edits or deletes it.
Future<void> showTrailPlace(
  BuildContext context,
  AppController app,
  TrailPlace place,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) {
    final l10n = sheet.l10n;
    final author = place.mine ? l10n.you : place.author ?? l10n.formerWalker;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, color: forest),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place.name,
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (place.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(place.comment),
            ),
          const SizedBox(height: 8),
          Text(
            '${l10n.placeAddedBy(author)} · ${DateFormat.yMMMd(l10n.localeName).format(place.updatedAt.toLocal())}',
            style: const TextStyle(fontSize: 12, color: mutedInk),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  place.origin == PlaceOrigin.onSite
                      ? Icons.verified_outlined
                      : Icons.upload_file_outlined,
                  size: 16,
                  color: forest,
                ),
                const SizedBox(width: 4),
                Text(
                  place.origin == PlaceOrigin.onSite
                      ? l10n.placeSeenOnSite
                      : l10n.placeImported,
                  style: const TextStyle(fontSize: 12, color: forest),
                ),
              ],
            ),
          ),
          if (place.pending)
            Text(l10n.placePending, style: const TextStyle(fontSize: 12)),
          if (place.mine)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final result = await showDialog<(String, String)>(
                      context: context,
                      builder: (_) => PlaceDialog(current: place),
                    );
                    if (result case (final name, final comment)) {
                      await app.editPlace(place, name, comment);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.edit),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(l10n.deletePlaceQuestion),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(l10n.delete),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) await app.deletePlace(place);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.delete),
                ),
              ],
            ),
        ],
      ),
    );
  },
);
