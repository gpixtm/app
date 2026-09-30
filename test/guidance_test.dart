import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/announce_progress.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/guide_navigation.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/guidance.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/trail_geometry.dart';
import 'package:gpix/domain/walk_recap.dart';
import 'package:gpix/l10n/generated/app_localizations.dart';
import 'package:gpix/presentation/guidance_text.dart';

import 'lifecycle_test.dart' show Repository, Maps, Elevation, Sync;

const metrePerDegree = 111194.93;
GeoPoint at(double north, double east) =>
    GeoPoint(north / metrePerDegree, east / metrePerDegree);

/// 300 m north, then 300 m east: one right turn at 300 m.
Trail corner() => Trail(
  id: 'corner',
  name: 'Corner',
  segments: [
    [at(0, 0), at(300, 0), at(300, 300)],
  ],
  pois: [],
);

class Announcement {
  const Announcement(this.instruction, this.speak, this.notify);
  final GuidanceInstruction instruction;
  final bool speak, notify;
}

class RecordingOutput implements GuidanceOutput {
  final said = <Announcement>[];
  var cleared = 0, prepared = 0;
  List<GuidanceInstruction> get instructions =>
      said.map((a) => a.instruction).toList();
  @override
  Future<bool> prepare() async {
    prepared++;
    return true;
  }

  @override
  Future<void> announce(
    GuidanceInstruction instruction, {
    required bool speak,
    required bool notify,
  }) async => said.add(Announcement(instruction, speak, notify));
  final recaps = <(WalkRecap, Set<RecapItem>, bool)>[];
  @override
  Future<void> summarize(
    WalkRecap recap, {
    required Set<RecapItem> spoken,
    required bool notify,
  }) async => recaps.add((recap, spoken, notify));
  @override
  Future<void> clear() async => cleared++;
}

/// Walk [path] in 10 m steps, one reliable fix every 2 seconds.
Future<void> walk(
  GuideNavigation guide,
  TrackingSession session,
  List<GeoPoint> path, {
  bool foreground = false,
}) async {
  var time = DateTime(2026, 9, 28, 10);
  for (final point in path) {
    time = time.add(const Duration(seconds: 2));
    final left = session.accept(Fix(point, 5, time), time);
    await guide.update(
      session,
      approach: false,
      leftTrail: left,
      foreground: foreground,
      now: time,
    );
  }
}

List<GeoPoint> northThenEast({int from = 0, int to = 600}) => [
  for (var d = from; d <= to; d += 10)
    d <= 300 ? at(d.toDouble(), 0) : at(300, d - 300.0),
];

void main() {
  test('a GPX corner becomes one turn at the vertex, mirrored in reverse', () {
    final geometry = TrailGeometry(corner());
    final turns = detectManeuvers(geometry);
    expect(turns, hasLength(1));
    expect(turns.single.kind, GuidanceKind.right);
    expect(turns.single.along, closeTo(300, 6));
    expect(turns.single.kind.mirrored, GuidanceKind.left);
  });

  test('recorded GPS jitter on a straight trail announces nothing', () {
    final trail = Trail(
      id: 'noisy',
      name: 'Noisy',
      segments: [
        [
          for (var d = 0; d <= 1000; d += 8)
            at(d.toDouble(), d % 16 == 0 ? 2 : -2),
        ],
      ],
      pois: [],
    );
    expect(detectManeuvers(TrailGeometry(trail)), isEmpty);
  });

  test('turn size is classified and a GPX segment gap creates no turn', () {
    expect(classifyTurn(20), isNull);
    expect(classifyTurn(-45), GuidanceKind.slightLeft);
    expect(classifyTurn(90), GuidanceKind.right);
    expect(classifyTurn(-150), GuidanceKind.sharpLeft);
    expect(classifyTurn(178), GuidanceKind.uTurnRight);
    final gap = Trail(
      id: 'gap',
      name: 'Gap',
      segments: [
        [at(0, 0), at(300, 0)],
        [at(600, 500), at(600, 900)],
      ],
      pois: [],
    );
    expect(detectManeuvers(TrailGeometry(gap)), isEmpty);
  });

  test(
    'announces about 100 m ahead, again when immediate, then arrival',
    () async {
      final output = RecordingOutput();
      final guide = GuideNavigation(output);
      final session = TrackingSession(TrailGeometry(corner()))..resume();
      await walk(guide, session, northThenEast());
      expect(output.instructions, const [
        GuidanceInstruction(GuidanceKind.right, 100),
        GuidanceInstruction(GuidanceKind.right),
        GuidanceInstruction(GuidanceKind.arrive),
      ]);
      expect(output.said.every((a) => a.speak && a.notify), isTrue);
    },
  );

  test(
    'reverse walking announces the mirrored turn and the other end',
    () async {
      final output = RecordingOutput();
      final guide = GuideNavigation(output);
      final session = TrackingSession(TrailGeometry(corner()))
        ..resume()
        ..reverse = true;
      await walk(guide, session, northThenEast().reversed.toList());
      expect(output.instructions, const [
        GuidanceInstruction(GuidanceKind.left, 100),
        GuidanceInstruction(GuidanceKind.left),
        GuidanceInstruction(GuidanceKind.arrive),
      ]);
    },
  );

  test(
    'starting near a turn announces it immediately with its real distance',
    () async {
      final output = RecordingOutput();
      final guide = GuideNavigation(output, voice: false);
      final session = TrackingSession(TrailGeometry(corner()))..resume();
      await walk(guide, session, [at(240, 0)], foreground: true);
      expect(output.instructions, const [
        GuidanceInstruction(GuidanceKind.right, 60),
      ]);
      // Visible map: no notification; voice preference disabled: silent.
      expect(output.said.single.notify, isFalse);
      expect(output.said.single.speak, isFalse);
    },
  );

  test(
    'direction notification off: spoken off-screen, nothing posted or cleared',
    () async {
      final output = RecordingOutput();
      final guide = GuideNavigation(output, notify: false);
      final session = TrackingSession(TrailGeometry(corner()))..resume();
      await walk(guide, session, northThenEast());
      expect(output.said, hasLength(3));
      expect(output.said.every((a) => a.speak && !a.notify), isTrue);
      await guide.leave();
      expect(output.cleared, 0);
    },
  );

  test(
    'directions and kilometre summary switch voice and notification apart',
    () async {
      final saved = <(AnnouncementSetting, bool)>[];
      final guide = GuideNavigation(RecordingOutput());
      final recap = AnnounceProgress(RecordingOutput());
      final app = AppController(
        library: Library(Repository(), XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: StreamGps(const Stream.empty()),
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
        guide: guide,
        recap: recap,
        saveAnnouncement: (setting, enabled) async =>
            saved.add((setting, enabled)),
      );
      await app.setAnnouncement(AnnouncementSetting.directionVoice, false);
      await app.setAnnouncement(
        AnnouncementSetting.directionNotification,
        false,
      );
      expect((guide.voice, guide.notify), (false, false));
      expect((recap.voice, recap.notify), (true, true));
      expect(app.announces(AnnouncementSetting.recapVoice), isTrue);
      await app.setAnnouncement(AnnouncementSetting.recapNotification, false);
      expect((recap.voice, recap.notify), (true, false));
      expect(saved, const [
        (AnnouncementSetting.directionVoice, false),
        (AnnouncementSetting.directionNotification, false),
        (AnnouncementSetting.recapNotification, false),
      ]);
      app.dispose();
    },
  );

  test('leaving the trail is announced and suppresses turn prompts', () async {
    final output = RecordingOutput();
    final guide = GuideNavigation(output);
    final session = TrackingSession(TrailGeometry(corner()))..resume();
    await walk(guide, session, [
      at(0, 0),
      at(10, 0),
      for (var d = 20; d <= 100; d += 10) at(d.toDouble(), 120),
    ]);
    expect(output.instructions, const [
      GuidanceInstruction(GuidanceKind.offTrail),
    ]);
  });

  test(
    'a trail starting near its end does not announce arrival at once',
    () async {
      final loop = Trail(
        id: 'loop',
        name: 'Loop',
        segments: [
          [at(0, 0), at(300, 0), at(300, 300), at(0, 300), at(0, 10)],
        ],
        pois: [],
      );
      final output = RecordingOutput();
      final guide = GuideNavigation(output);
      final session = TrackingSession(TrailGeometry(loop))..resume();
      await walk(guide, session, [at(0, 20), at(0, 25)]);
      expect(
        output.instructions.where((i) => i.kind == GuidanceKind.arrive),
        isEmpty,
      );
    },
  );

  test(
    'controller announces from live fixes and clears when navigation stops',
    () async {
      final output = RecordingOutput();
      final positions = StreamController<Fix>.broadcast();
      final repository = Repository();
      final app = AppController(
        library: Library(repository, XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: StreamGps(positions.stream),
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
        guide: GuideNavigation(output),
      );
      app.select(corner());
      await app.start();
      expect(output.prepared, 1);
      positions.add(Fix(at(210, 0), 5, DateTime.now()));
      await pumpEventQueue();
      expect(output.instructions, const [
        GuidanceInstruction(GuidanceKind.right, 90),
      ]);
      expect(app.upcomingManeuver?.kind, GuidanceKind.right);
      expect(app.upcomingManeuver?.metres, closeTo(90, 6));
      app.stop();
      await pumpEventQueue();
      expect(output.cleared, 0, reason: 'nothing was posted while visible');
      app.dispose();
      await positions.close();
    },
  );

  test('both languages describe every instruction with whole sentences', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    const soon = GuidanceInstruction(GuidanceKind.left, 100);
    expect(describeGuidance(en, soon), (
      title: 'Turn left',
      body: 'In 100 m',
      speech: 'In 100 metres, turn left',
    ));
    expect(describeGuidance(fr, soon), (
      title: 'Tournez à gauche',
      body: 'Dans 100 m',
      speech: 'Dans 100 mètres, tournez à gauche',
    ));
    expect(
      describeGuidance(fr, const GuidanceInstruction(GuidanceKind.right)).body,
      'Maintenant',
    );
    for (final l10n in [en, fr]) {
      for (final kind in GuidanceKind.values) {
        for (final metres in [null, 10, 100]) {
          final text = describeGuidance(
            l10n,
            GuidanceInstruction(kind, kind.turn ? metres : null),
          );
          expect(text.title, isNotEmpty, reason: '$kind');
          expect(text.speech, isNotEmpty, reason: '$kind');
        }
      }
    }
  });
}

class StreamGps implements PositionSource {
  StreamGps(this.stream);
  final Stream<Fix> stream;
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => stream;
}
