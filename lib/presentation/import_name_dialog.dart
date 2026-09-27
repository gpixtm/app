import 'localization.dart';

import 'package:flutter/material.dart';

import '../data/gpx_text.dart';

class ImportNameDialog extends StatefulWidget {
  const ImportNameDialog({super.key});
  @override
  State<ImportNameDialog> createState() => _ImportNameDialogState();
}

class _ImportNameDialogState extends State<ImportNameDialog> {
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, input.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.unreadableFilename),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.unreadableFilenameInfo),
            TextFormField(
              controller: input,
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.trailName),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.enterName
                  : damagedText(value)
                  ? context.l10n.replaceDamagedText
                  : null,
              onFieldSubmitted: (_) => submit(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(onPressed: submit, child: Text(context.l10n.importAction)),
    ],
  );
}
