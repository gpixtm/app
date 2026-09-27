import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/coverage.dart';
import 'package:gpix/domain/trail_geometry.dart';

Trail trail(List<List<GeoPoint>> s) =>
    Trail(id: 't', name: 'test', segments: s, pois: []);
void main() {
  test('GPX namespaces, segments, missing elevation and POI-only import', () {
    const xml =
        '<gpx xmlns="http://www.topografix.com/GPX/1/1"><wpt lat="43" lon="-1"><name>Fontaine</name><desc>Eau</desc></wpt><trk><name>Chemin</name><trkseg><trkpt lat="43" lon="-1"><ele>100</ele></trkpt><trkpt lat="43.01" lon="-1"/></trkseg><trkseg><trkpt lat="44" lon="-1"/><trkpt lat="44.01" lon="-1"/></trkseg></trk></gpx>';
    final result = XmlGpxDecoder().decode(xml, 'file');
    expect(result.length, 2);
    expect(result.first.segments.length, 2);
    expect(result.last.followable, false);
    expect(result.last.pois.single.name, 'Fontaine');
    final geometry = TrailGeometry(result.first);
    expect(geometry.total, closeTo(2224, 5));
    expect(geometry.profile[1].elevation, isNull);
    expect(geometry.profile[2].distance, geometry.profile[1].distance);
    expect(geometry.orientedProfile(true).first.distance, 0);
  });
  test('invalid coordinates and XML entities fail visibly', () {
    expect(
      () => XmlGpxDecoder().decode('<gpx><wpt lat="91" lon="1"/></gpx>', 'bad'),
      throwsFormatException,
    );
    expect(
      () => XmlGpxDecoder().decode('<!DOCTYPE gpx><gpx/>', 'bad'),
      throwsFormatException,
    );
  });
  test('mid-route start and reversal share exact distance axis', () {
    final g = TrailGeometry(
      trail([
        [const GeoPoint(0, 0), const GeoPoint(0, .02)],
      ]),
    );
    final p = g.project(const GeoPoint(0, .01))!;
    expect(p.along, closeTo(g.total / 2, 1));
    expect(p.offTrail, lessThan(1));
    expect(g.remaining(p, false), closeTo(g.remaining(p, true), 1));
    final s = TrackingSession(g)..resume();
    final now = DateTime.utc(2026);
    s.accept(Fix(const GeoPoint(0, .01), 5, now), now);
    expect(s.startAlong, closeTo(p.along, 1));
    s.invert();
    expect(s.reverse, true);
  });
  test('overlapping return leg stays on previous branch', () {
    final g = TrailGeometry(
      trail([
        [const GeoPoint(0, 0), const GeoPoint(0, .01), const GeoPoint(0, 0)],
      ]),
    );
    final p = g.project(
      const GeoPoint(0, .005),
      previous: g.total * .75,
      maxTravel: 30,
    )!;
    expect(p.along, closeTo(g.total * .75, 1));
  });
  test('no alerts for stale or inaccurate fixes; sustained deviation only', () {
    final s = TrackingSession(
      TrailGeometry(
        trail([
          [const GeoPoint(0, 0), const GeoPoint(0, .02)],
        ]),
      ),
    )..resume();
    final now = DateTime.utc(2026);
    expect(s.accept(Fix(const GeoPoint(.01, .01), 100, now), now), false);
    expect(
      s.accept(
        Fix(
          const GeoPoint(.01, .01),
          5,
          now.subtract(const Duration(seconds: 20)),
        ),
        now,
      ),
      false,
    );
    for (var i = 0; i < 3; i++) {
      final t = now.add(Duration(seconds: i));
      expect(s.accept(Fix(const GeoPoint(.01, .01), 5, t), t), i == 2);
    }
    s.muted = true;
    s.pause();
    expect(s.accept(Fix(const GeoPoint(.02, .01), 5, now), now), false);
  });
  test('regional union checks sparse edges, not just vertices', () {
    final t = trail([
      [const GeoPoint(0, 0), const GeoPoint(0, 2)],
    ]);
    expect(
      Coverage([const Bounds(-1, -1, 1, 1), const Bounds(1, -1, 3, 1)])
          .covers(t),
      true,
    );
    expect(
      Coverage([const Bounds(-1, -1, .5, 1), const Bounds(1.5, -1, 3, 1)])
          .covers(t),
      false,
    );
  });
}
