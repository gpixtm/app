import 'dart:math' as math;

import 'models.dart';
import 'walk_recording.dart';

/// Body and carried weight used for energy estimates. Account data: it
/// follows the walker to another phone.
class WalkerProfile {
  const WalkerProfile({this.weightKg, this.packKg});
  static const minimumWeight = 25.0, maximumWeight = 300.0, maximumPack = 60.0;
  final double? weightKg, packKg;

  /// Total moved mass; unknown without a body weight.
  double? get massKg => weightKg == null ? null : weightKg! + (packKg ?? 0);

  static bool validWeight(double? value) =>
      value == null || (value >= minimumWeight && value <= maximumWeight);
  static bool validPack(double? value) =>
      value == null || (value >= 0 && value <= maximumPack);

  Map<String, Object?> toJson() => {'weightKg': weightKg, 'packKg': packKg};
  static WalkerProfile fromJson(Map<String, dynamic> json) => WalkerProfile(
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    packKg: (json['packKg'] as num?)?.toDouble(),
  );
  @override
  bool operator ==(Object other) =>
      other is WalkerProfile &&
      other.weightKg == weightKg &&
      other.packKg == packKg;
  @override
  int get hashCode => Object.hash(weightKg, packKg);
}

/// Active (net of resting) energy of a recorded walk, in kcal.
///
/// Oxygen cost per stretch of about [stretch] metres, from speed and slope:
/// ACSM walking equation on level and uphill ground (0.1·v + 1.8·v·grade,
/// v in m/min), ACSM running equation above 8 km/h, and on descents the
/// level cost scaled by Minetti et al. (2002)'s gradient cost ratio, since
/// ACSM does not model negative slopes. 1 L of O₂ ≈ 5 kcal. Altitudes are
/// smoothed over ±[smoothing] metres to absorb GPS noise; missing altitudes
/// count as level ground, stops and GPS gaps add nothing.
double? activeCalories(
  List<WalkSample> samples,
  double? massKg, {
  double stretch = 100,
  double smoothing = 40,
}) {
  if (massKg == null || massKg <= 0) return null;
  var kcal = 0.0;
  var start = 0;
  while (start < samples.length) {
    var end = start + 1;
    while (end < samples.length &&
        samples[end].segment == samples[start].segment) {
      end++;
    }
    kcal += _segmentCalories(
      samples.sublist(start, end),
      massKg,
      stretch,
      smoothing,
    );
    start = end;
  }
  return kcal;
}

double _segmentCalories(
  List<WalkSample> samples,
  double mass,
  double stretch,
  double smoothing,
) {
  if (samples.length < 2) return 0;
  final along = [0.0];
  for (var i = 1; i < samples.length; i++) {
    along.add(along.last + distance(samples[i - 1].point, samples[i].point));
  }
  double? smoothed(int i) {
    var sum = 0.0, count = 0;
    for (var j = i; j >= 0 && along[i] - along[j] <= smoothing; j--) {
      if (samples[j].point.elevation case final e?) {
        sum += e;
        count++;
      }
    }
    for (
      var j = i + 1;
      j < samples.length && along[j] - along[i] <= smoothing;
      j++
    ) {
      if (samples[j].point.elevation case final e?) {
        sum += e;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  var kcal = 0.0;
  var from = 0;
  while (from < samples.length - 1) {
    var to = from + 1;
    var metres = 0.0, seconds = 0.0;
    while (true) {
      final step = samples[to].time.difference(samples[to - 1].time);
      final gap = step.inMilliseconds / 1000;
      // A GPS gap is not walking time; its distance is not counted either.
      if (gap > 0 && gap <= 30) {
        metres += along[to] - along[to - 1];
        seconds += gap;
      }
      if (metres >= stretch || to == samples.length - 1) break;
      to++;
    }
    if (seconds > 0 && metres > 0) {
      final a = smoothed(from), b = smoothed(to);
      final grade = a == null || b == null || metres < 10
          ? 0.0
          : ((b - a) / metres).clamp(-.45, .45);
      final speed = metres / seconds * 60; // m/min
      if (speed >= 12) {
        kcal += _oxygen(speed, grade) * mass * (seconds / 60) / 1000 * 5;
      }
    }
    from = to;
  }
  return kcal;
}

/// Net oxygen cost in ml/kg/min.
double _oxygen(double speed, double grade) {
  if (speed > 134) {
    return 0.2 * speed + 0.9 * speed * math.max(grade, 0);
  }
  if (grade >= 0) return 0.1 * speed + 1.8 * speed * grade;
  return 0.1 * speed * _minetti(grade) / _minetti(0);
}

/// Minetti et al. (2002) cost of walking, J/kg/m, valid from −45% to +45%.
double _minetti(double i) =>
    280.5 * math.pow(i, 5) -
    58.7 * math.pow(i, 4) -
    76.8 * math.pow(i, 3) +
    51.9 * i * i +
    19.6 * i +
    2.5;

/// Profile cached on this phone; [pending] until the server has it.
abstract interface class ProfileStore {
  Future<({WalkerProfile profile, bool pending})> read();
  Future<void> save(WalkerProfile profile, {required bool pending});
}

abstract interface class ProfileTransport {
  Future<WalkerProfile> fetch();
  Future<void> send(WalkerProfile profile);
}
