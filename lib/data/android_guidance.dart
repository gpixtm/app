import 'package:flutter/services.dart';

import '../domain/guidance.dart';
import '../domain/walk_recap.dart';

/// Localized sentences for an instruction, supplied by the composition root.
typedef GuidanceSentences =
    ({String title, String body, String speech}) Function(
      GuidanceInstruction instruction,
    );

/// Localized title and one sentence per available kilometre-summary item.
typedef RecapSentences =
    ({String title, Map<RecapItem, String> lines}) Function(WalkRecap recap);

/// Android notifications and the device's offline text-to-speech engine.
class AndroidGuidance implements GuidanceOutput {
  AndroidGuidance({
    required this.sentences,
    required this.recapSentences,
    required this.languageCode,
    this.channel = const MethodChannel('gpix/guidance'),
  });
  final GuidanceSentences sentences;
  final RecapSentences recapSentences;
  final String Function() languageCode;
  final MethodChannel channel;

  @override
  Future<bool> prepare() async =>
      await channel.invokeMethod<bool>('prepare') ?? false;

  @override
  Future<void> announce(
    GuidanceInstruction instruction, {
    required bool speak,
    required bool notify,
  }) async {
    if (!speak && !notify) return;
    final text = sentences(instruction);
    await channel.invokeMethod<void>('announce', {
      'kind': instruction.kind.name,
      'title': text.title,
      'body': text.body,
      'speech': text.speech,
      'language': languageCode(),
      'speak': speak,
      'notify': notify,
    });
  }

  @override
  Future<void> summarize(
    WalkRecap recap, {
    required Set<RecapItem> spoken,
    required bool notify,
  }) async {
    if (spoken.isEmpty && !notify) return;
    final text = recapSentences(recap);
    final lines = [
      for (final item in RecapItem.values)
        if (text.lines[item] case final line?) (item, line),
    ];
    final said = [
      for (final (item, line) in lines)
        if (spoken.contains(item)) line,
    ];
    await channel.invokeMethod<void>('announce', {
      'kind': 'recap',
      'title': text.title,
      'body': lines.map((l) => l.$2).join('\n'),
      'speech': said.isEmpty ? '' : '${text.title}. ${said.join(' ')}',
      'language': languageCode(),
      'speak': said.isNotEmpty,
      'notify': notify,
    });
  }

  @override
  Future<void> clear() => channel.invokeMethod<void>('clear');
}
