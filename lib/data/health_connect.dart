import 'package:flutter/services.dart';

import '../domain/health_data.dart';

class AndroidHealthConnect implements HealthDataSource {
  const AndroidHealthConnect();
  static const channel = MethodChannel('gpix/health');
  Future<HealthAvailability> _status(String method) async {
    final value = await channel.invokeMethod<String>(method);
    return HealthAvailability.values.firstWhere(
      (v) => v.name == value,
      orElse: () => HealthAvailability.unavailable,
    );
  }

  @override
  Future<HealthAvailability> status() => _status('status');
  @override
  Future<HealthAvailability> authorize() => _status('authorize');
  @override
  Future<HealthSummary> read(DateTime start, DateTime end) async {
    final value = await channel.invokeMapMethod<String, dynamic>('read', {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    });
    return HealthSummary(
      readAt: DateTime.now().toUtc(),
      sources: List<String>.from(value?['sources'] ?? []),
      steps: (value?['steps'] as num?)?.toInt(),
      activeCalories: (value?['activeCalories'] as num?)?.toDouble(),
      averageHeartRate: (value?['averageHeartRate'] as num?)?.toDouble(),
      maxHeartRate: (value?['maxHeartRate'] as num?)?.toDouble(),
    );
  }

  @override
  Future<void> openSettings() => channel.invokeMethod('settings');
  @override
  Future<void> openZepp() => channel.invokeMethod('zepp');
}
