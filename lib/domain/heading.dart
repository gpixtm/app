import 'dart:math' as math;

double angleDifference(double target, double source) =>
    (target - source + 540) % 360 - 180;

/// Circular time-based filter. Never interpolates 359 -> 1 through south.
class HeadingFilter {
  HeadingFilter({required this.seconds, this.deadband = 0});
  final double seconds, deadband;
  double? value;
  DateTime? _time;
  double? add(double heading, DateTime time) {
    if (!heading.isFinite) return value;
    final dt = _time == null
        ? 10.0
        : time.difference(_time!).inMicroseconds / 1e6;
    if (dt <= 0) return value;
    _time = time;
    if (value == null || dt > 3) return value = heading % 360;
    final difference = angleDifference(heading, value!);
    if (difference.abs() > deadband) {
      value = (value! + difference * (1 - math.exp(-dt / seconds))) % 360;
    }
    return value;
  }
}
