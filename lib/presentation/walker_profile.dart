import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../domain/walk_energy.dart';
import 'localization.dart';

/// Body and backpack weight used to estimate active calories.
class WalkerProfileCard extends StatefulWidget {
  const WalkerProfileCard(this.app, {super.key});
  final AppController app;
  @override
  State<WalkerProfileCard> createState() => _WalkerProfileCardState();
}

class _WalkerProfileCardState extends State<WalkerProfileCard> {
  late final weight = TextEditingController(
    text: _text(widget.app.walker.weightKg),
  );
  late final pack = TextEditingController(
    text: _text(widget.app.walker.packKg),
  );
  bool weightInvalid = false, packInvalid = false;

  static String _text(double? value) => value == null
      ? ''
      : value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  /// Accepts a decimal comma; an empty field means unknown.
  static (double?, bool) _parse(String text) {
    final trimmed = text.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return (null, true);
    final value = double.tryParse(trimmed);
    return (value, value != null && value.isFinite);
  }

  @override
  void dispose() {
    weight.dispose();
    pack.dispose();
    super.dispose();
  }

  void save() {
    final (body, bodyParsed) = _parse(weight.text);
    final (carried, packParsed) = _parse(pack.text);
    setState(() {
      weightInvalid = !bodyParsed || !WalkerProfile.validWeight(body);
      packInvalid = !packParsed || !WalkerProfile.validPack(carried);
    });
    if (weightInvalid || packInvalid) return;
    widget.app.saveProfile(WalkerProfile(weightKg: body, packKg: carried));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.local_fire_department_outlined),
      title: Text(context.l10n.walkerProfile),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Text(context.l10n.walkerProfileInfo),
        if (widget.app.walker.weightKg == null &&
            widget.app.healthWeightKg != null) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.healthWeightUsed(
              NumberFormat(
                '0.#',
                context.l10n.localeName,
              ).format(widget.app.healthWeightKg),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.bodyWeight,
                  errorText: weightInvalid
                      ? context.l10n.invalidBodyWeight
                      : null,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: pack,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.packWeight,
                  errorText: packInvalid
                      ? context.l10n.invalidPackWeight
                      : null,
                  errorMaxLines: 3,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: save, child: Text(context.l10n.save)),
        ),
      ],
    ),
  );
}
