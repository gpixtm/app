import '../domain/guidance.dart';
import '../domain/ports.dart';
import '../domain/route_history.dart';
import '../domain/trail_statistics.dart';
import '../domain/trail_geometry.dart';
import '../domain/walk_metrics.dart';
import '../domain/usual_kilometres.dart';
import '../domain/walk_recap.dart';
import '../domain/walk_recording.dart';

/// Summarizes the walk at each recorded kilometre, with or without a GPX.
class AnnounceProgress {
  AnnounceProgress(
    this.output, {
    this.statistics,
    this.library,
    Set<RecapItem>? spoken,
    this.voice = true,
    this.notify = true,
    this.every = 1000,
  }) : spoken = spoken ?? RecapItem.spokenByDefault;
  final GuidanceOutput output;
  final TrailStatisticsStore? statistics;

  /// Earlier walks, for the usual speed of each kilometre.
  final TrailRepository? library;
  final double every;
  Set<RecapItem> spoken;

  /// Independent of direction guidance: the summary has its own switches.
  bool voice;
  bool notify;

  WalkRecording? _recording;
  int _kilometre = 0;
  int? _boundarySeconds;
  bool _posted = false;
  Future<UsualKilometres?>? _usual;

  /// [session] is the followed GPX, if any; approach routes have no remaining
  /// GPX distance of their own.
  Future<void> update(
    WalkRecording recording, {
    required DateTime now,
    required bool foreground,
    TrackingSession? session,
  }) async {
    if (!identical(recording, _recording)) {
      // New or restored recording: start counting from where it already is.
      _recording = recording;
      _usual = null;
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
    final split = _boundarySeconds, from = _kilometre;
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
      from: from,
    );
    final notify = this.notify && !foreground;
    if (notify) _posted = true;
    try {
      await output.summarize(
        recap,
        spoken: voice ? spoken : const {},
        notify: notify,
      );
    } catch (_) {
      // Delivery must never interrupt the recording.
    }
  }

  /// Last summary of the whole walk, when it finishes at the end of the
  /// followed trail, with the average speed of the whole walk. Nothing is left
  /// to walk, so remaining distance and arrival are left out. Said after any
  /// direction change in progress; its notification stays once the walk is
  /// finished.
  Future<void> conclude(
    WalkRecording recording, {
    required DateTime now,
    required bool foreground,
  }) async {
    _recording = null;
    final recap = await _recap(
      recording,
      (recording.metres / every).floor(),
      recording.seconds(now),
      now,
      null,
      null,
      finished: true,
    );
    final notify = this.notify && !foreground;
    // The finished walk's summary replaces the last kilometre's: keep it.
    _posted = false;
    try {
      await output.summarize(
        recap,
        spoken: voice ? spoken : const {},
        notify: notify,
      );
    } catch (_) {
      // Delivery must never prevent saving the walk.
    }
  }

  Future<WalkRecap> _recap(
    WalkRecording recording,
    int kilometre,
    int seconds,
    DateTime now,
    TrackingSession? session,
    double? splitKmh, {
    int? from,
    bool finished = false,
  }) async {
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
    // A kilometre is compared with the usual speed of that same kilometre;
    // without one it is not compared, rather than with the whole route.
    final usualKmh = finished
        ? usual?.averageKmh
        : splitKmh == null || from == null
        ? null
        : (await (_usual ??= _usualKilometres(
            recording,
            now,
          )))?.kmh(from, kilometre);
    return WalkRecap(
      kilometre: kilometre,
      metres: recording.metres,
      activeSeconds: seconds,
      clock: now,
      // Each kilometre announces its own pace; the finished walk its whole one.
      averageKmh: finished ? average : splitKmh,
      remainingMetres: remaining,
      arrival: remaining != null && average != null && average > .5
          ? now.add(Duration(seconds: (remaining / (average / 3.6)).round()))
          : null,
      usualKmh: usualKmh,
      usualOfKilometre: !finished,
      previousWalks: usual?.walks,
      ascent: metrics.hasElevation ? metrics.ascent : null,
      steps: snapshot.walk!.steps,
      calories: snapshot.walk!.estimatedCalories,
      finished: finished,
    );
  }

  /// Usual speed of each kilometre over the counted walks of the same route
  /// in the same direction, measured once per recording.
  Future<UsualKilometres?> _usualKilometres(
    WalkRecording recording,
    DateTime now,
  ) async {
    final library = this.library;
    final source = recording.saved.walk?.statisticsTrailId;
    if (library == null || source == null) return null;
    try {
      final trails = await library.all();
      final history = groupWalks(
        trails.where(
          (t) =>
              t.walk?.statisticsTrailId == source && t.id != recording.saved.id,
        ),
        trails.where((t) => t.id == source),
      ).firstOrNull;
      if (history == null) return null;
      final route = history.route;
      final reversed = route == null
          ? null
          : RouteIndex(route).measure(recording.snapshot(now)).reversed;
      return UsualKilometres([
        for (final walk in history.counted)
          if (reversed == null || walk.reversed == reversed) walk.walk,
      ], every: every);
    } catch (_) {
      return null;
    }
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
