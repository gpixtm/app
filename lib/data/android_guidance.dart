import 'package:flutter/services.dart';

import '../domain/guidance.dart';

/// Localized sentences for an instruction, supplied by the composition root.
typedef GuidanceSentences =
    ({String title, String body, String speech}) Function(
      GuidanceInstruction instruction,
    );

/// Android notifications and the device's offline text-to-speech engine.
class AndroidGuidance implements GuidanceOutput {
  AndroidGuidance({
    required this.sentences,
    required this.languageCode,
    this.channel = const MethodChannel('gpix/guidance'),
  });
  final GuidanceSentences sentences;
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
  Future<void> clear() => channel.invokeMethod<void>('clear');
}
