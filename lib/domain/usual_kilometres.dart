import 'models.dart';
import 'walk_metrics.dart';

/// Active seconds since the start at each whole [every] metres of [walk]'s
/// recorded distance, starting with 0. Segment gaps add no distance, as in
/// the live summary. Empty for a walk without samples.
List<double> kilometreTimes(Trail walk, {double every = 1000}) {
  final samples = walk.walk?.samples ?? const [];
  if (samples.isEmpty) return const [];
  final times = activeTimeline(walk);
  final result = [0.0];
  var walked = 0.0;
  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1], b = samples[i];
    if (a.segment != b.segment) continue;
    final step = distance(a.point, b.point);
    while (step > 0 && walked + step >= every * result.length) {
      final f = (every * result.length - walked) / step;
      result.add(times[i - 1] + (times[i] - times[i - 1]) * f);
    }
    walked += step;
  }
  return result;
}

/// Usual speed of each kilometre of a route, from earlier walks of it: a
/// climb is compared with the usual climb, not with the whole route.
class UsualKilometres {
  UsualKilometres(Iterable<Trail> walks, {this.every = 1000}) {
    for (final walk in walks) {
      final times = kilometreTimes(walk, every: every);
      for (var k = 1; k < times.length; k++) {
        if (_seconds.length < k) {
          _seconds.add(0);
          _walks.add(0);
        }
        _seconds[k - 1] += times[k] - times[k - 1];
        _walks[k - 1]++;
      }
    }
  }
  final double every;
  final _seconds = <double>[];
  final _walks = <int>[];

  /// Usual km/h from the end of kilometre [from] to the end of kilometre [to]
  /// (counted from 1, kilometre 0 being the start). Null unless earlier walks
  /// covered every kilometre in between.
  double? kmh(int from, int to) {
    if (from < 0 || to <= from || to > _seconds.length) return null;
    var seconds = 0.0;
    for (var k = from; k < to; k++) {
      seconds += _seconds[k] / _walks[k];
    }
    return seconds > 0 ? (to - from) * every / seconds * 3.6 : null;
  }
}
