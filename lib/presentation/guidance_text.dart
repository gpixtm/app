import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/guidance.dart';
import '../domain/walk_recap.dart';
import '../l10n/generated/app_localizations.dart';

typedef GuidanceText = ({String title, String body, String speech});

/// Localized kilometre summary: one whole sentence per available item.
({String title, Map<RecapItem, String> lines}) describeRecap(
  AppLocalizations l10n,
  WalkRecap recap,
) {
  final locale = l10n.localeName;
  final speed = NumberFormat('0.0', locale);
  String km(double metres) =>
      NumberFormat('#,##0.#', locale).format(metres / 1000);
  final time = DateFormat.jm(locale);
  final minutes = recap.activeSeconds ~/ 60;
  final difference = recap.difference;
  final lines = <RecapItem, String>{
    RecapItem.distance: l10n.recapDistance(km(recap.metres)),
    RecapItem.duration: minutes < 60
        ? l10n.recapDurationMinutes(minutes)
        : l10n.recapDurationHours(minutes ~/ 60, minutes % 60),
    if (recap.splitKmh case final split?)
      RecapItem.currentSpeed: l10n.recapCurrentSpeed(speed.format(split)),
    if (recap.averageKmh case final average?)
      RecapItem.averageSpeed: l10n.recapAverageSpeed(speed.format(average)),
    if (difference != null)
      RecapItem.comparison: [
        // Compare at the announced precision so "0.0 faster" never occurs.
        switch (double.parse(difference.toStringAsFixed(1))) {
          0 => l10n.recapAsUsual(speed.format(recap.usualKmh)),
          > 0 => l10n.recapFaster(
            speed.format(difference),
            speed.format(recap.usualKmh),
          ),
          _ => l10n.recapSlower(
            speed.format(-difference),
            speed.format(recap.usualKmh),
          ),
        },
        if (recap.previousWalks case final count?)
          l10n.recapPreviousWalks(count),
      ].join(' '),
    if (recap.remainingMetres case final remaining?)
      RecapItem.remaining: l10n.recapRemaining(km(remaining)),
    if (recap.arrival case final arrival?)
      RecapItem.arrival: l10n.recapArrival(time.format(arrival)),
    if (recap.ascent case final ascent?)
      RecapItem.ascent: l10n.recapAscent(ascent.round()),
    RecapItem.clock: l10n.recapClock(time.format(recap.clock)),
  };
  return (title: l10n.recapTitle(recap.kilometre), lines: lines);
}

String recapItemLabel(AppLocalizations l10n, RecapItem item) => switch (item) {
  RecapItem.distance => l10n.recapItemDistance,
  RecapItem.duration => l10n.recapItemDuration,
  RecapItem.currentSpeed => l10n.recapItemCurrentSpeed,
  RecapItem.averageSpeed => l10n.recapItemAverageSpeed,
  RecapItem.comparison => l10n.recapItemComparison,
  RecapItem.remaining => l10n.recapItemRemaining,
  RecapItem.arrival => l10n.recapItemArrival,
  RecapItem.ascent => l10n.recapItemAscent,
  RecapItem.clock => l10n.recapItemClock,
};

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
