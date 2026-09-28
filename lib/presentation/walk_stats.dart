import 'localization.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../domain/walk_metrics.dart';
import 'design.dart';

String durationLabel(int seconds) =>
    '${seconds ~/ 3600} h ${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}';
String dateLabel(DateTime value) {
  final d = value.toLocal();
  return DateFormat.yMd().add_jm().format(d);
}

class WalkStats extends StatelessWidget {
  const WalkStats(this.trail, {super.key});
  final Trail trail;
  @override
  Widget build(BuildContext context) {
    final m = WalkMetrics(trail), health = trail.walk?.health;
    final steps = trail.walk?.bestSteps;
    final estimate = trail.walk?.estimatedCalories;
    final pace = m.paceSeconds?.round();
    final values = <String, String>{
      context.l10n.distanceWalked: kilometers(m.metres),
      context.l10n.activeDuration: durationLabel(m.activeSeconds),
      context.l10n.totalDuration: durationLabel(m.elapsedSeconds),
      context.l10n.averageSpeed: m.averageKmh == null
          ? '—'
          : '${decimal(m.averageKmh!)} km/h',
      context.l10n.averagePace: pace == null
          ? '—'
          : '${pace ~/ 60}:${(pace % 60).toString().padLeft(2, '0')} /km',
      context.l10n.maxGpsSpeed: m.maxKmh == null
          ? '—'
          : '${decimal(m.maxKmh!)} km/h',
      context.l10n.ascent: m.hasElevation ? '+${m.ascent.round()} m' : '—',
      context.l10n.descent: m.hasElevation ? '−${m.descent.round()} m' : '—',
      context.l10n.altitude: m.lastAltitude == null
          ? '—'
          : '${m.lastAltitude!.round()} m',
      context.l10n.minMaxAltitude: m.minimumAltitude == null
          ? '—'
          : '${m.minimumAltitude!.round()} / ${m.maximumAltitude!.round()} m',
      context.l10n.averageHeartRate: health?.averageHeartRate == null
          ? '—'
          : '${health!.averageHeartRate!.round()} bpm',
      context.l10n.maxHeartRate: health?.maxHeartRate == null
          ? '—'
          : '${health!.maxHeartRate!.round()} bpm',
      context.l10n.steps: steps == null
          ? '—'
          : NumberFormat.decimalPattern(context.l10n.localeName).format(steps),
      // A watch measurement, once imported, replaces the phone's estimate.
      context.l10n.activeCalories: health?.activeCalories != null
          ? '${health!.activeCalories!.round()} kcal'
          : estimate == null
          ? '—'
          : context.l10n.estimatedCalories(estimate.round()),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (_, size) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in values.entries)
                SizedBox(
                  width: (size.maxWidth - 8) / 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xfff0f3ed),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(entry.key, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(context.l10n.statsExplanation, style: TextStyle(fontSize: 11)),
        if (estimate == null && health?.activeCalories == null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.caloriesNeedWeight,
            style: const TextStyle(fontSize: 11),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          health == null
              ? context.l10n.noImportedWatchData
              : context.l10n.healthSources(
                  dateLabel(health.readAt),
                  health.sources.join(", "),
                ),
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
