import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/route_history.dart';
import 'package:gpix/domain/walk_recording.dart';

const latitude = 45.0;
final metreOfLongitude = 1 / (111320 * math.cos(latitude * math.pi / 180));
const metreOfLatitude = 1 / 110574;

GeoPoint east(double metres, [double north = 0]) =>
    GeoPoint(latitude + north * metreOfLatitude, 2 + metres * metreOfLongitude);

/// A straight 2 km route heading east.
final straight = Trail(
  id: 'route',
  name: 'Straight',
  segments: [
    [for (var m = 0.0; m <= 2000; m += 100) east(m)],
  ],
  pois: const [],
);

/// A 400 m square loop that starts and ends at the same corner.
final loop = Trail(
  id: 'loop',
  name: 'Loop',
  segments: [
    [east(0), east(100), east(100, 100), east(0, 100), east(0)],
  ],
  pois: const [],
);

/// A walk along [path] (metres east, metres north) at [speed] m/s, one
/// sample every five metres, split into segments at each index in [breaks]
/// after a [pause].
Trail walkAlong(
  String id,
  List<(double, double)> path, {
  double speed = 1.4,
  DateTime? started,
  String? sourceTrailId,
  String? routeId,
  Set<int> breaks = const {},
  Duration pause = Duration.zero,
  bool finished = true,
}) {
  final start = started ?? DateTime(2026, 9, 1, 9);
  final samples = <WalkSample>[];
  var time = start, segment = 0;
  for (var i = 0; i < path.length; i++) {
    if (i > 0) {
      final metres = math.sqrt(
        math.pow(path[i].$1 - path[i - 1].$1, 2) +
            math.pow(path[i].$2 - path[i - 1].$2, 2),
      );
      time = time.add(Duration(milliseconds: (metres / speed * 1000).round()));
    }
    if (breaks.contains(i)) {
      segment++;
      time = time.add(pause);
    }
    samples.add(WalkSample(time, east(path[i].$1, path[i].$2), 5, segment));
  }
  final segments = <List<GeoPoint>>[];
  for (final s in samples) {
    if (segments.length <= s.segment) segments.add([]);
    segments.last.add(s.point);
  }
  final active =
      time.difference(start).inSeconds - pause.inSeconds * breaks.length;
  return Trail(
    id: id,
    name: id,
    segments: segments,
    pois: const [],
    walk: WalkDetails(
      started: start,
      ended: finished ? time : null,
      seconds: active,
      sourceTrailId: sourceTrailId,
      routeId: routeId,
      samples: samples,
    ),
  );
}

List<(double, double)> eastward(double from, double to) => [
  for (var m = from; from <= to ? m <= to : m >= to; m += from <= to ? 5 : -5)
    (m, 0),
];

void main() {
  test('walks of one route form one entry, most recently walked first', () {
    final older = walkAlong(
      'older',
      eastward(0, 2000),
      sourceTrailId: 'route',
      started: DateTime(2026, 3, 1),
    );
    final created = walkAlong(
      'free',
      eastward(0, 500),
      started: DateTime(2026, 5, 1),
    );
    final recent = walkAlong(
      'recent',
      eastward(0, 2000),
      routeId: 'route',
      started: DateTime(2026, 9, 1),
    );
    final groups = groupWalks([older, created, recent], [straight]);
    expect(groups.map((g) => g.id), ['route', 'free']);
    expect(groups.first.name, 'Straight');
    expect(groups.first.walks.map((w) => w.walk.id), ['recent', 'older']);
    expect(groups.first.free, isFalse);
    expect(groups.last.route, isNull);
    expect(groups.last.latest.coverage, isNull);
    expect(groups.last.latest.complete, isTrue);
  });

  test('a partial walk is kept but left out of records and usual speed', () {
    final whole = walkAlong('whole', eastward(0, 2000), sourceTrailId: 'route');
    final half = walkAlong(
      'half',
      eastward(0, 1000),
      speed: 3,
      sourceTrailId: 'route',
      started: DateTime(2026, 9, 2),
    );
    final group = groupWalks([whole, half], [straight]).single;
    final measured = {for (final w in group.walks) w.walk.id: w};
    expect(measured['whole']!.coverage, greaterThan(.97));
    expect(measured['whole']!.complete, isTrue);
    expect(measured['half']!.coverage, closeTo(.5, .03));
    expect(measured['half']!.complete, isFalse);
    expect(group.fastest!.walk.id, 'whole');
    expect(group.usualKmh(), closeTo(1.4 * 3.6, .1));
    expect(group.usualKmh(except: measured['whole']), isNull);
  });

  test('a walk in the opposite direction is recognised as reversed', () {
    final back = walkAlong('back', eastward(2000, 0), sourceTrailId: 'route');
    final walk = groupWalks([back], [straight]).single.latest;
    expect(walk.reversed, isTrue);
    expect(walk.coverage, greaterThan(.97));
    expect(walk.progress!.start, lessThan(10));
    expect(walk.progress!.end, greaterThan(1990));
  });

  test('a loop is followed round without jumping to its other end', () {
    final path = [
      for (var m = 0.0; m <= 100; m += 5) (m, 0.0),
      for (var m = 5.0; m <= 100; m += 5) (100.0, m),
      for (var m = 95.0; m >= 0; m -= 5) (m, 100.0),
      for (var m = 95.0; m >= 0; m -= 5) (0.0, m),
    ];
    final walk = groupWalks(
      [walkAlong('round', path, sourceTrailId: 'loop')],
      [loop],
    ).single.latest;
    expect(walk.reversed, isFalse);
    expect(walk.coverage, greaterThan(.95));
    expect(walk.progress!.end, greaterThan(390));
    // Time grows steadily with distance: about 1.4 m/s all the way round.
    expect(walk.progress!.secondsAt(200)!, closeTo(200 / 1.4, 5));
  });

  test('pauses add no time to the progress along the route', () {
    final paused = walkAlong(
      'paused',
      eastward(0, 2000),
      breaks: {200},
      pause: const Duration(minutes: 20),
      sourceTrailId: 'route',
    );
    final walk = groupWalks([paused], [straight]).single.latest;
    expect(walk.progress!.secondsAt(1900)!, closeTo(1900 / 1.4, 10));
  });

  test('the gap shows where the faster walk gained its lead', () {
    final fast = walkAlong('fast', eastward(0, 2000), sourceTrailId: 'route');
    final slow = walkAlong(
      'slow',
      eastward(0, 2000),
      speed: 1,
      sourceTrailId: 'route',
      started: DateTime(2026, 9, 3),
    );
    final group = groupWalks([fast, slow], [straight]).single;
    final a = group.walks.firstWhere((w) => w.walk.id == 'fast');
    final b = group.walks.firstWhere((w) => w.walk.id == 'slow');
    final gap = progressGap(a, b);
    expect(gap.first.$2, closeTo(0, 1));
    // 2 km at 1 m/s against 1.4 m/s: about 571 seconds behind at the end.
    expect(gap.last.$2, closeTo(2000 / 1 - 2000 / 1.4, 15));
    expect(progressGap(b, a).last.$2, lessThan(0));
    final back = groupWalks(
      [walkAlong('back', eastward(2000, 0), sourceTrailId: 'route')],
      [straight],
    ).single.latest;
    expect(progressGap(a, back), isEmpty);
  });

  test('a guided walk keeps its route once the trail left the phone', () {
    final guided = walkAlong(
      'guided',
      eastward(0, 2000),
      sourceTrailId: 'gone',
    );
    final withReference = Trail(
      id: guided.id,
      name: guided.name,
      segments: guided.segments,
      pois: const [],
      walk: WalkDetails(
        started: guided.walk!.started,
        ended: guided.walk!.ended,
        seconds: guided.walk!.seconds,
        sourceTrailId: 'gone',
        samples: guided.walk!.samples,
        reference: WalkReference('Old trail', straight.segments),
      ),
    );
    final group = groupWalks([withReference], const []).single;
    expect(group.name, 'Old trail');
    expect(group.route, isNotNull);
    expect(group.latest.coverage, greaterThan(.97));
  });

  test('a walk still recording counts for nothing yet', () {
    final ongoing = walkAlong(
      'ongoing',
      eastward(0, 2000),
      speed: 3,
      finished: false,
      sourceTrailId: 'route',
    );
    final group = groupWalks([ongoing], [straight]).single;
    expect(group.latest.counted, isFalse);
    expect(group.fastest, isNull);
    expect(group.longest, isNull);
  });
  test('measurements are reused with the current walk details', () {
    final measures = RouteMeasures();
    final walk = walkAlong('walk', eastward(0, 1000), sourceTrailId: 'route');
    final first = groupWalks([walk], [straight], measures: measures);
    final renamed = Trail(
      id: walk.id,
      name: 'Renamed',
      segments: walk.segments,
      pois: const [],
      walk: walk.walk,
    );
    final again = groupWalks([renamed], [straight], measures: measures);
    expect(again.single.latest.walk.name, 'Renamed');
    expect(
      identical(again.single.latest.progress, first.single.latest.progress),
      isTrue,
    );
    // A longer recording of the same walk is measured again.
    final longer = walkAlong('walk', eastward(0, 2000), sourceTrailId: 'route');
    final remeasured = groupWalks([longer], [straight], measures: measures);
    expect(remeasured.single.latest.coverage, greaterThan(.97));
  });
}
