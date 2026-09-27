import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/data/health_connect.dart';
import 'package:gpix/domain/health_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = AndroidHealthConnect();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidHealthConnect.channel, (call) async {
          calls.add(call);
          if (call.method == 'status' || call.method == 'authorize') {
            return 'needsPermission';
          }
          if (call.method == 'read') {
            return {
              'steps': null,
              'averageHeartRate': 110,
              'maxHeartRate': 135,
              'sources': ['com.huami.watch.hmwatchmanager'],
            };
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidHealthConnect.channel, null),
  );
  test('partial or denied permissions never imply a connected watch', () async {
    expect(await source.status(), HealthAvailability.needsPermission);
    expect(await source.authorize(), HealthAvailability.needsPermission);
    expect(calls.where((c) => c.method == 'read'), isEmpty);
  });
  test('health read uses the requested UTC walk interval and preserves missing measurements', () async {
    final start = DateTime.utc(2026, 9, 1, 10),
        end = DateTime.utc(2026, 9, 1, 11);
    final summary = await source.read(start, end);
    expect(calls.single.arguments, {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    });
    expect(summary.averageHeartRate, 110);
    expect(summary.steps, isNull);
    expect(summary.activeCalories, isNull);
    expect(summary.sources, ['com.huami.watch.hmwatchmanager']);
  });
}
