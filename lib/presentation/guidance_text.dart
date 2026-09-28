import 'package:flutter/material.dart';

import '../domain/guidance.dart';
import '../l10n/generated/app_localizations.dart';

typedef GuidanceText = ({String title, String body, String speech});

/// Localized notification and speech sentences for one instruction.
GuidanceText describeGuidance(
  AppLocalizations l10n,
  GuidanceInstruction instruction,
) {
  final metres = instruction.metres;
  final title = guidanceTitle(l10n, instruction.kind);
  if (instruction.kind == GuidanceKind.offTrail) {
    return (title: title, body: l10n.guidanceOffTrailBody, speech: title);
  }
  if (!instruction.kind.turn) return (title: title, body: '', speech: title);
  if (metres == null) {
    return (title: title, body: l10n.guidanceNow, speech: title);
  }
  final speech = switch (instruction.kind) {
    GuidanceKind.slightLeft => l10n.guidanceSlightLeftIn(metres),
    GuidanceKind.left => l10n.guidanceLeftIn(metres),
    GuidanceKind.sharpLeft => l10n.guidanceSharpLeftIn(metres),
    GuidanceKind.slightRight => l10n.guidanceSlightRightIn(metres),
    GuidanceKind.right => l10n.guidanceRightIn(metres),
    GuidanceKind.sharpRight => l10n.guidanceSharpRightIn(metres),
    _ => l10n.guidanceUTurnIn(metres),
  };
  return (title: title, body: l10n.inMetres(metres), speech: speech);
}

String guidanceTitle(AppLocalizations l10n, GuidanceKind kind) =>
    switch (kind) {
      GuidanceKind.slightLeft => l10n.guidanceSlightLeft,
      GuidanceKind.left => l10n.guidanceLeft,
      GuidanceKind.sharpLeft => l10n.guidanceSharpLeft,
      GuidanceKind.uTurnLeft || GuidanceKind.uTurnRight => l10n.guidanceUTurn,
      GuidanceKind.slightRight => l10n.guidanceSlightRight,
      GuidanceKind.right => l10n.guidanceRight,
      GuidanceKind.sharpRight => l10n.guidanceSharpRight,
      GuidanceKind.arrive => l10n.guidanceArrive,
      GuidanceKind.reachTrail => l10n.guidanceReachTrail,
      GuidanceKind.offTrail => l10n.guidanceOffTrail,
    };

/// Same pictograms as the native notification icons.
IconData guidanceIcon(GuidanceKind kind) => switch (kind) {
  GuidanceKind.slightLeft => Icons.turn_slight_left,
  GuidanceKind.left => Icons.turn_left,
  GuidanceKind.sharpLeft => Icons.turn_sharp_left,
  GuidanceKind.uTurnLeft => Icons.u_turn_left,
  GuidanceKind.slightRight => Icons.turn_slight_right,
  GuidanceKind.right => Icons.turn_right,
  GuidanceKind.sharpRight => Icons.turn_sharp_right,
  GuidanceKind.uTurnRight => Icons.u_turn_right,
  GuidanceKind.arrive || GuidanceKind.reachTrail => Icons.flag,
  GuidanceKind.offTrail => Icons.wrong_location_outlined,
};
