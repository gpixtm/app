import 'package:flutter/services.dart';

import '../domain/walk_recording.dart';

/// Android hardware step counter (TYPE_STEP_COUNTER), screen-off capable.
class AndroidStepCounter implements StepCounter {
  const AndroidStepCounter([this.channel = const MethodChannel('gpix/steps')]);
  final MethodChannel channel;
  @override
  Future<bool> start() async =>
      await channel.invokeMethod<bool>('start') ?? false;
  @override
  Future<int?> read() => channel.invokeMethod<int>('read');
  @override
  Future<void> stop() => channel.invokeMethod<void>('stop');
}
