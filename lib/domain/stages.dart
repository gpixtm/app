import 'catalogue.dart';
import 'models.dart';
import 'trail_geometry.dart';

/// A trail's place among the numbered stages of an itinerary, with the
/// stages just before and after it in the itinerary's order.
class StageLinks {
  const StageLinks({
    required this.group,
    required this.stage,
    this.previous,
    this.next,
  });
  final TrailGroupSummary group;
  final int stage;
  final TrailGroupMember? previous, next;

  /// Where the trail [trailId] is a stage of [group], or null when it is not
  /// one of its numbered stages.
  static StageLinks? of(TrailGroup group, String trailId) {
    final stages = [
      for (final m in group.members)
        if (m.role == MemberRole.stage && m.trail != null) m,
    ];
    final index = stages.indexWhere((m) => m.trail!.id == trailId);
    if (index < 0) return null;
    return StageLinks(
      group: group.summary,
      stage: stages[index].stage ?? index + 1,
      previous: index > 0 ? stages[index - 1] : null,
      next: index + 1 < stages.length ? stages[index + 1] : null,
    );
  }

  /// The itinerary holding a trail as a numbered stage, from its details: the
  /// group directly holding it in the first path where it is a stage.
  static TrailGroupSummary? itinerary(TrailDetails? details) {
    for (final path in details?.paths ?? const <TrailGroupPath>[]) {
      if (path.role == MemberRole.stage && path.groups.isNotEmpty) {
        return path.groups.last;
      }
    }
    return null;
  }

  /// The neighbouring stage a walker standing at [position] goes on to, and
  /// whether to walk it backwards: the one with an end nearest to them.
  /// Stages are not always drawn in the itinerary's direction, so their
  /// order alone does not tell it. Null when neither ends within [reach].
  NextStage? following(GeoPoint position, {double reach = maximumStageGap}) {
    NextStage? best;
    var nearest = reach;
    for (final member in [?previous, ?next]) {
      final line = member.trail!.outline.where((s) => s.isNotEmpty).toList();
      if (line.isEmpty) continue;
      final start = distance(position, line.first.first);
      final end = distance(position, line.last.last);
      final gap = start <= end ? start : end;
      if (gap <= nearest) {
        nearest = gap;
        best = NextStage(member, reverse: end < start);
      }
    }
    return best;
  }
}

/// How far the end of one stage may lie from the start of the next.
const maximumStageGap = 1000.0;

/// The stage to walk next and in which direction.
class NextStage {
  const NextStage(this.member, {required this.reverse});
  final TrailGroupMember member;
  final bool reverse;
  String get trailId => member.trail!.id;
}

/// The walker reached the end of the trail being followed, in the direction
/// walked: a reliable fix, on the line, less than 50 m from its end, after
/// walking some of it. Starting a trail right at its end does not count.
bool trailEndReached(TrackingSession session, DateTime now) {
  final fix = session.fix, p = session.projection, start = session.startAlong;
  if (!session.active || fix == null || p == null || start == null) {
    return false;
  }
  final total = session.geometry.total;
  final walked = (p.along - start).abs();
  return fix.reliable(now) &&
      fix.accuracy <= 25 &&
      p.offTrail <= 40 &&
      session.geometry.remaining(p, session.reverse) < 50 &&
      walked >= (total * .3 < 300 ? total * .3 : 300);
}

/// Where a walk over several days goes on from [position]: the same trail in
/// the direction last walked, or the next stage when the walker already
/// stands at or beyond the end of this one.
class Continuation {
  const Continuation({required this.reverse, this.stage});

  /// Walk backwards along the chosen trail.
  final bool reverse;

  /// The next stage to walk instead of the route itself.
  final NextStage? stage;

  static Continuation of(
    Trail route,
    GeoPoint position, {
    required bool reversed,
    StageLinks? links,
  }) {
    final geometry = TrailGeometry(route);
    final here = geometry.project(position);
    final stay = Continuation(reverse: reversed);
    if (links == null || here == null) return stay;
    final line = route.segments.where((s) => s.isNotEmpty).toList();
    if (line.isEmpty) return stay;
    // The end reached in the direction walked, where the next stage begins.
    final end = reversed ? line.first.first : line.last.last;
    final next = links.following(end);
    if (next == null) return stay;
    final ahead = geometry.remaining(here, reversed);
    final onNext = TrailGeometry(
      Trail(
        id: next.trailId,
        name: '',
        segments: next.member.trail!.outline,
        pois: const [],
      ),
    ).project(position)?.offTrail;
    if (onNext == null) return stay;
    // Nearer the next stage than this one, or at the end of this one.
    if (onNext < here.offTrail ||
        (ahead < 100 && onNext <= here.offTrail + 50)) {
      return Continuation(reverse: next.reverse, stage: next);
    }
    return stay;
  }
}
