import 'models.dart';
import 'health_data.dart';
import 'trail_geometry.dart';
import 'walk_energy.dart';

class WalkSample {
  const WalkSample(this.time, this.point, this.accuracy, this.segment);
  final DateTime time;
  final GeoPoint point;
  final double accuracy;
  final int segment;
}

/// The trail a guided walk followed, simplified, so history still shows it
/// once that trail is no longer on the phone.
class WalkReference {
  const WalkReference(this.name, this.segments);
  final String name;
  final List<List<GeoPoint>> segments;
}

class WalkDetails {
  const WalkDetails({
    required this.started,
    required this.seconds,
    this.ended,
    this.sourceTrailId,
    this.routeId,
    this.samples = const [],
    this.health,
    this.reference,
    this.steps,
    this.estimatedCalories,
  });
  final DateTime started;
  final DateTime? ended;
  final int seconds;

  /// GPX followed during the walk; null for a free walk.
  final String? sourceTrailId;

  /// Route a free walk created or matched; it counts in that route's statistics.
  final String? routeId;
  final List<WalkSample> samples;
  final HealthSummary? health;
  final WalkReference? reference;

  /// Steps counted by the phone while recording; null when unavailable.
  final int? steps;

  /// Active kcal estimated from the track and the walker's weight.
  final double? estimatedCalories;

  /// Watch measurements, once imported, are preferred to the phone's.
  int? get bestSteps => health?.steps ?? steps;
  double? get bestCalories => health?.activeCalories ?? estimatedCalories;

  /// GPX whose running statistics include this walk.
  String? get statisticsTrailId => routeId ?? sourceTrailId;
  WalkDetails withHealth(HealthSummary summary) => WalkDetails(
    started: started,
    ended: ended,
    seconds: seconds,
    sourceTrailId: sourceTrailId,
    routeId: routeId,
    samples: samples,
    health: summary,
    reference: reference,
    steps: steps,
    estimatedCalories: estimatedCalories,
  );
}

/// The phone's hardware step counter.
abstract interface class StepCounter {
  /// Start counting; false when the sensor is missing or access refused.
  Future<bool> start();

  /// Cumulative counter value, null before the first sensor event.
  Future<int?> read();
  Future<void> stop();
}

abstract interface class RecordingStore {
  Future<Trail?> read();
  Future<void> write(Trail recording);
  Future<void> clear();
}

/// Observed positions, never snapped to the planned GPX. Pauses and GPS gaps
/// create new segments so the history never invents a straight line across them.
class WalkRecording {
  WalkRecording(this.saved)
    : segments = saved.segments.map((s) => s.toList()).toList(),
      samples = [...saved.walk!.samples],
      health = saved.walk!.health,
      _savedSteps = saved.walk!.steps,
      metres = TrailGeometry(saved).total;
  final Trail saved;

  /// Total moved mass for the calorie estimate; null leaves it absent.
  double? massKg;

  // Steps of earlier active periods, and the phone counter at this period's start.
  int? _savedSteps, _stepBase, _liveSteps;
  int? get steps => _savedSteps == null && _liveSteps == null
      ? null
      : (_savedSteps ?? 0) + (_liveSteps ?? 0);

  /// [counter] is the phone's cumulative step counter. Only active periods
  /// count; a counter reset (phone restart) continues from the last value.
  void countSteps(int counter) {
    if (!active) return;
    final base = _stepBase;
    if (base == null || counter < base) {
      _savedSteps = (_savedSteps ?? 0) + (_liveSteps ?? 0);
      _liveSteps = 0;
      _stepBase = counter;
      return;
    }
    _liveSteps = counter - base;
  }

  /// Recorded distance, kept incrementally; pauses and gaps add nothing.
  double metres;
  HealthSummary? health;
  final List<List<GeoPoint>> segments;
  final List<WalkSample> samples;
  DateTime? _resumed, _lastAccepted, _lastFix;
  int _elapsed = 0;
  bool _newSegment = true;
  bool get active => _resumed != null;
  int seconds(DateTime now) =>
      saved.walk!.seconds +
      _elapsed +
      (_resumed == null
          ? 0
          : now.difference(_resumed!).inSeconds.clamp(0, 1 << 30));
  void resume(DateTime now) {
    if (active) return;
    _resumed = now;
    _newSegment = true;
    _lastAccepted = null;
    _lastFix = null;
  }

  void pause(DateTime now) {
    if (_resumed != null) {
      _elapsed += now.difference(_resumed!).inSeconds.clamp(0, 1 << 30);
    }
    _resumed = null;
    _newSegment = true;
    if (_liveSteps != null) _savedSteps = (_savedSteps ?? 0) + _liveSteps!;
    _liveSteps = null;
    _stepBase = null;
  }

  bool accept(Fix fix, DateTime now) {
    if (!active || !fix.reliable(now)) {
      _newSegment = true;
      return false;
    }
    if (_lastAccepted != null && !fix.time.isAfter(_lastAccepted!)) {
      return false;
    }
    if (samples.isNotEmpty && !fix.time.isAfter(samples.last.time)) {
      return false;
    }
    final gap = _lastAccepted == null
        ? null
        : fix.time.difference(_lastAccepted!).inMilliseconds / 1000;
    if (_lastFix != null && fix.time.difference(_lastFix!).inSeconds > 30) {
      _newSegment = true;
    }
    _lastFix = fix.time;
    if (!_newSegment && segments.isNotEmpty && segments.last.isNotEmpty) {
      final metres = distance(segments.last.last, fix.point);
      if (metres < 3) return false;
      if (gap != null && metres > 7 * gap + fix.accuracy) return false;
    }
    if (_newSegment) {
      segments.add([]);
      _newSegment = false;
    } else if (segments.last.isNotEmpty) {
      metres += distance(segments.last.last, fix.point);
    }
    segments.last.add(fix.point);
    samples.add(
      WalkSample(fix.time, fix.point, fix.accuracy, segments.length - 1),
    );
    _lastAccepted = fix.time;
    return true;
  }

  Trail snapshot(
    DateTime now, {
    bool finished = false,
    String? routeId,
    String? name,
  }) => Trail(
    id: saved.id,
    name: name ?? saved.name,
    segments: segments,
    pois: [],
    walk: WalkDetails(
      started: saved.walk!.started,
      ended: finished ? now : null,
      seconds: seconds(now),
      sourceTrailId: saved.walk!.sourceTrailId,
      routeId: routeId ?? saved.walk!.routeId,
      samples: List.unmodifiable(samples),
      health: health,
      reference: saved.walk!.reference,
      steps: steps,
      estimatedCalories:
          activeCalories(samples, massKg) ?? saved.walk!.estimatedCalories,
    ),
  );
}
