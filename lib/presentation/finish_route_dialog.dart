import 'localization.dart';

import 'package:flutter/material.dart';

import '../data/gpx_text.dart';

/// What the walker writes about a route when finishing it.
typedef RouteDetails = ({String name, String description});

/// Confirms the end of a free walk and names the route it becomes.
class FinishRouteDialog extends StatefulWidget {
  const FinishRouteDialog({required this.suggestedName, super.key});
  final String suggestedName;
  @override
  State<FinishRouteDialog> createState() => _FinishRouteDialogState();
}

class _FinishRouteDialogState extends State<FinishRouteDialog> {
  late final name = TextEditingController(text: widget.suggestedName);
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop<RouteDetails>(context, (
        name: name.text.trim(),
        description: description.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.finishRouteQuestion),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.finishRouteInfo),
            const SizedBox(height: 12),
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.l10n.trailName),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.enterName
                  : damagedText(value)
                  ? context.l10n.replaceDamagedText
                  : null,
            ),
            TextFormField(
              controller: description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.routeDescriptionOptional,
              ),
              validator: (value) => value != null && damagedText(value)
                  ? context.l10n.replaceDamagedText
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.continueAction),
      ),
      FilledButton(onPressed: submit, child: Text(context.l10n.saveWalk)),
    ],
  );
}
