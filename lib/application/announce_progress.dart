import '../domain/guidance.dart';
import '../domain/trail_statistics.dart';
import '../domain/trail_geometry.dart';
import '../domain/walk_metrics.dart';
import '../domain/walk_recap.dart';
import '../domain/walk_recording.dart';

/// Summarizes the walk at each recorded kilometre, with or without a GPX.
class AnnounceProgress {
  AnnounceProgress(
    this.output, {
    this.statistics,
    Set<RecapItem>? spoken,
    this.every = 1000,
  }) : spoken = spoken ?? RecapItem.spokenByDefault;
  final GuidanceOutput output;
  final TrailStatisticsStore? statistics;
  final double every;
  Set<RecapItem> spoken;

  WalkRecording? _recording;
  int _kilometre = 0;
  int? _boundarySeconds;
  bool _posted = false;

  /// [session] is the followed GPX, if any; approach routes have no remaining
  /// GPX distance of their own.
  Future<void> update(
    WalkRecording recording, {
    required DateTime now,
    required bool voice,
    required bool foreground,
    TrackingSession? session,
  }) async {
    if (!identical(recording, _recording)) {
      // New or restored recording: start counting from where it already is.
      _recording = recording;
      _kilometre = (recording.metres / every).floor();
      _boundarySeconds = recording.metres < every / 10
          ? recording.seconds(now)
          : null;
      return;
    }
    final kilometre = (recording.metres / every).floor();
    if (kilometre <= _kilometre) return;
    final seconds = recording.seconds(now);
    final walked = (kilometre - _kilometre) * every;
    final split = _boundarySeconds;
    _kilometre = kilometre;
    _boundarySeconds = seconds;
    final recap = await _recap(
      recording,
      kilometre,
      seconds,
      now,
      session,
      split == null || seconds <= split
          ? null
          : walked / (seconds - split) * 3.6,
    );
    if (!foreground) _posted = true;
    try {
      await output.summarize(
        recap,
        spoken: voice ? spoken : const {},
        notify: !foreground,
      );
    } catch (_) {
      // Delivery must never interrupt the recording.
    }
  }

  Future<WalkRecap> _recap(
    WalkRecording recording,
    int kilometre,
    int seconds,
    DateTime now,
    TrackingSession? session,
    double? splitKmh,
  ) async {
    final snapshot = recording.snapshot(now);
    final metrics = WalkMetrics(snapshot, now: now);
    final average = seconds > 0 ? recording.metres / seconds * 3.6 : null;
    final p = session?.projection;
    final remaining = session != null && p != null && !session.offTrail
        ? session.geometry.remaining(p, session.reverse)
        : null;
    TrailStatistics? usual;
    final source = recording.saved.walk?.statisticsTrailId;
    if (source != null) {
      try {
        usual = await statistics?.find(source);
      } catch (_) {}
    }
    return WalkRecap(
      kilometre: kilometre,
      metres: recording.metres,
      activeSeconds: seconds,
      clock: now,
      splitKmh: splitKmh,
      averageKmh: average,
      remainingMetres: remaining,
      arrival: remaining != null && average != null && average > .5
          ? now.add(Duration(seconds: (remaining / (average / 3.6)).round()))
          : null,
      usualKmh: usual?.averageKmh,
      previousWalks: usual?.walks,
      ascent: metrics.hasElevation ? metrics.ascent : null,
    );
  }

  Future<void> leave() async {
    _recording = null;
    if (!_posted) return;
    _posted = false;
    try {
      await output.clear();
    } catch (_) {}
  }
}
