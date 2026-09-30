import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/announce_progress.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/collaborative_trails.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/record_walk.dart';
import 'package:gpix/data/catalogue_codec.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/app_message.dart';
import 'package:gpix/domain/catalogue.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/shared_trails.dart';
import 'package:gpix/domain/stages.dart';
import 'package:gpix/domain/trail_geometry.dart';
import 'package:gpix/domain/walk_recap.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:gpix/l10n/generated/app_localizations.dart';
import 'package:gpix/presentation/trail_details.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'collaborative_trails_test.dart' show FakeTransport;
import 'guidance_test.dart' show RecordingOutput;
import 'lifecycle_test.dart' show Maps, Gps, Elevation, Sync, Repository;

/// A line due north along longitude 6, from [from] to [to] degrees of
/// latitude, one point every ~110 m.
List<GeoPoint> north(double from, double to) {
  final steps = ((to - from).abs() / .001).round();
  return [
    for (var i = 0; i <= steps; i++)
      GeoPoint(from + (to - from) * i / steps, 6.0),
  ];
}

SharedTrail stageTrail(String id, List<GeoPoint> line) => SharedTrail(
  id: id,
  name: 'GR 15 – $id',
  metres: TrailGeometry(
    Trail(id: id, name: id, segments: [line], pois: const []),
  ).total,
  outline: [line],
  source: 'osm',
  ref: 'GR 15',
);

const gr15 = TrailGroupSummary(
  id: 'gr15',
  kind: TrailGroupKind.itinerary,
  name: 'GR 15',
  metres: 3300,
  trailCount: 4,
  source: 'osm',
  ref: 'GR 15',
);

/// Stages 5, 6 and 7 follow each other northwards; stage 7 is drawn from
/// its far end, as open data sometimes is. A variant sits between them.
final stage5 = stageTrail('stage-5', north(44.99, 45.0));
final stage6 = stageTrail('stage-6', north(45.0, 45.01));
final stage7 = stageTrail('stage-7', north(45.02, 45.01));
final variant = stageTrail('variant', north(45.0, 45.005));
final itinerary = TrailGroup(
  summary: gr15,
  members: [
    TrailGroupMember(MemberRole.stage, stage: 1, trail: stage5),
    TrailGroupMember(MemberRole.variant, trail: variant),
    TrailGroupMember(MemberRole.stage, stage: 2, trail: stage6),
    TrailGroupMember(MemberRole.stage, stage: 3, trail: stage7),
  ],
);

TrailDetails stageDetails(int stage, {List<TrailGroupPath> also = const []}) =>
    TrailDetails(
      source: 'osm',
      fields: const {'ref': 'GR 15'},
      paths: [
        ...also,
        TrailGroupPath(const [gr15], MemberRole.stage, stage: stage),
      ],
    );

/// Another itinerary where stage 7 of the GR 15 is its sixth stage.
const tour = TrailGroupSummary(
  id: 'tour',
  kind: TrailGroupKind.itinerary,
  name: 'Tour du massif',
  metres: 6000,
  trailCount: 6,
  source: 'osm',
);
const walkerCollection = TrailGroupSummary(
  id: 'mine',
  kind: TrailGroupKind.collection,
  name: 'Mes étapes',
  metres: 0,
  trailCount: 1,
  source: walkerSource,
);

Trail full(SharedTrail t) => Trail(
  id: t.id,
  name: t.name,
  segments: t.outline,
  pois: const [],
).withPublicId(t.id);

class MemoryRecording implements RecordingStore {
  Trail? saved;
  @override
  Future<Trail?> read() async => saved;
  @override
  Future<void> write(Trail recording) async => saved = recording;
  @override
  Future<void> clear() async => saved = null;
}

class LiveGps implements PositionSource {
  final positions = StreamController<Fix>.broadcast();
  @override
  Future<void> requestAccess() async {}
  @override
  Stream<Fix> watch() => positions.stream;
}

class StageTransport extends FakeTransport {
  final details = <String, TrailDetails>{};
  @override
  Future<CatalogueTrail> trail(String id) async {
    final opened = await super.trail(id);
    return CatalogueTrail(opened.trail, details[id] ?? opened.details);
  }
}

void main() {
  group('stages of an itinerary', () {
    test('the stages before and after skip variants, in order', () {
      final links = StageLinks.of(itinerary, 'stage-6')!;
      expect(links.group.id, 'gr15');
      expect(links.stage, 2);
      expect(links.previous!.trail!.id, 'stage-5');
      expect(links.next!.trail!.id, 'stage-7');
      expect(StageLinks.of(itinerary, 'stage-5')!.previous, isNull);
      expect(StageLinks.of(itinerary, 'stage-7')!.next, isNull);
      expect(StageLinks.of(itinerary, 'variant'), isNull);
      expect(StageLinks.holding(stageDetails(2))!.id, 'gr15');
      expect(
        StageLinks.holding(
          stageDetails(
            2,
            also: [
              TrailGroupPath(const [walkerCollection], MemberRole.stage),
            ],
          ),
        )!.id,
        'gr15',
        reason: 'an itinerary before a collection',
      );
      expect(
        StageLinks.holding(
          const TrailDetails(
            source: 'osm',
            paths: [
              TrailGroupPath([gr15], MemberRole.variant),
            ],
          ),
        ),
        isNull,
      );
    });

    test('the next stage is the neighbour starting where the walker is', () {
      final links = StageLinks.of(itinerary, 'stage-6')!;
      // At the north end of stage 6: stage 7 is drawn from its far end.
      final ahead = links.following(const GeoPoint(45.0101, 6.0))!;
      expect(ahead.trailId, 'stage-7');
      expect(ahead.reverse, isTrue);
      // Walked backwards, stage 6 ends at its start, where stage 5 ends.
      final back = links.following(const GeoPoint(44.9999, 6.0))!;
      expect(back.trailId, 'stage-5');
      expect(back.reverse, isTrue);
      expect(links.following(const GeoPoint(45.1, 6.0)), isNull);
    });

    test('the end is reached only after walking part of the trail', () {
      final t0 = DateTime(2026, 9, 28, 9);
      TrackingSession walk(List<GeoPoint> points, {bool reverse = false}) {
        final session = TrackingSession(TrailGeometry(full(stage6)))
          ..resume()
          ..reverse = reverse;
        for (final (i, p) in points.indexed) {
          final time = t0.add(Duration(minutes: 10 * i));
          session.accept(Fix(p, 8, time), time);
        }
        return session;
      }

      DateTime at(int fixes) => t0.add(Duration(minutes: 10 * (fixes - 1)));
      final walked = walk([
        const GeoPoint(45.002, 6.0),
        const GeoPoint(45.006, 6.0),
        const GeoPoint(45.0098, 6.0),
      ]);
      expect(trailEndReached(walked, at(3)), isTrue);
      expect(
        trailEndReached(walked, at(3).add(const Duration(minutes: 1))),
        isFalse,
        reason: 'an old fix is not trusted',
      );
      final started = walk([const GeoPoint(45.0098, 6.0)]);
      expect(trailEndReached(started, at(1)), isFalse);
      final notYet = walk([
        const GeoPoint(45.002, 6.0),
        const GeoPoint(45.008, 6.0),
      ]);
      expect(trailEndReached(notYet, at(2)), isFalse);
      final backwards = walk(reverse: true, [
        const GeoPoint(45.008, 6.0),
        const GeoPoint(45.0002, 6.0),
      ]);
      expect(trailEndReached(backwards, at(2)), isTrue);
      final wrongEnd = walk(reverse: true, [
        const GeoPoint(45.002, 6.0),
        const GeoPoint(45.0098, 6.0),
      ]);
      expect(trailEndReached(wrongEnd, at(2)), isFalse);
      expect(trailEndReached(walked..pause(), at(3)), isFalse);
    });

    test('a walk goes on the next day where the walker stands', () {
      final route = full(stage6);
      final links = StageLinks.of(itinerary, 'stage-6')!;
      final middle = Continuation.of(
        route,
        const GeoPoint(45.004, 6.0005),
        reversed: false,
        links: links,
      );
      expect(middle.stage, isNull);
      expect(middle.reverse, isFalse);
      expect(
        Continuation.of(
          route,
          const GeoPoint(45.004, 6.0),
          reversed: true,
          links: links,
        ).reverse,
        isTrue,
        reason: 'the direction of the last walk is kept',
      );
      // Slept at the end of stage 6: the day starts on stage 7.
      final atEnd = Continuation.of(
        route,
        const GeoPoint(45.0099, 6.0003),
        reversed: false,
        links: links,
      );
      expect(atEnd.stage!.trailId, 'stage-7');
      expect(atEnd.reverse, isTrue, reason: 'stage 7 is drawn from its end');
      // Already some way along stage 7.
      final beyond = Continuation.of(
        route,
        const GeoPoint(45.014, 6.0),
        reversed: false,
        links: links,
      );
      expect(beyond.stage!.trailId, 'stage-7');
      // Walking backwards, stage 5 comes next.
      final south = Continuation.of(
        route,
        const GeoPoint(44.997, 6.0),
        reversed: true,
        links: links,
      );
      expect(south.stage!.trailId, 'stage-5');
      expect(south.reverse, isTrue);
      final single = Continuation.of(
        route,
        const GeoPoint(45.0099, 6.0),
        reversed: false,
      );
      expect(single.stage, isNull, reason: 'a single trail just goes on');
    });
  });

  group('itineraries kept on the phone', () {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('gpix-stages');
    });
    tearDown(() => dir.delete(recursive: true));

    test('a group survives encoding with its stages and outlines', () {
      final decoded = CatalogueCodec.fullGroup(
        CatalogueCodec.encodeFullGroup(itinerary),
      );
      expect(decoded.summary.name, 'GR 15');
      expect(decoded.summary.kind, TrailGroupKind.itinerary);
      expect(decoded.members.map((m) => (m.role, m.stage, m.trail!.id)), [
        (MemberRole.stage, 1, 'stage-5'),
        (MemberRole.variant, null, 'variant'),
        (MemberRole.stage, 2, 'stage-6'),
        (MemberRole.stage, 3, 'stage-7'),
      ]);
      expect(decoded.members.last.trail!.outline.single.first.lat, 45.02);
      expect(decoded.members.last.trail!.name, 'GR 15 – stage-7');
      expect(StageLinks.of(decoded, 'stage-6')!.next!.trail!.id, 'stage-7');
    });

    test('upgrading a version 4 database keeps its data and adds the '
        'itinerary cache', () async {
      final path = '${dir.path}/v4.sqlite';
      final v4 = await openDatabase(
        path,
        version: 4,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE trails (id TEXT PRIMARY KEY, payload TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0, mutation TEXT NOT NULL, public_id TEXT)',
          );
          await db.execute(
            'CREATE TABLE outbox (sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, operation TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, deleted INTEGER NOT NULL, base INTEGER, blocked INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE maps (id TEXT PRIMARY KEY, manifest TEXT NOT NULL, path TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE trail_statistics (trail_id TEXT PRIMARY KEY, walks INTEGER NOT NULL, metres REAL NOT NULL, seconds INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE trail_reviews (trail_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE trail_places (id TEXT PRIMARY KEY, trail_id TEXT NOT NULL, change INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL, pending TEXT, version INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE catalogue_details (trail_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
        },
      );
      await SqliteTrailRepository(v4).keep(full(stage6));
      await SqliteSharedTrailStore(v4).keepDetails('stage-6', stageDetails(2));
      await SqliteTrailRepository(v4).save(
        Trail(
          id: 'walk',
          name: 'Étape du Grand Ballon 🥾',
          segments: [north(45.0, 45.005)],
          pois: const [],
        ),
      );
      await v4.close();
      final upgraded = await openLocalDatabase(path);
      expect(await upgraded.getVersion(), 5);
      final store = SqliteSharedTrailStore(upgraded);
      expect((await store.details('stage-6'))!.paths.single.stage, 2);
      expect(
        (await SqliteTrailRepository(upgraded).all()).map((t) => t.name),
        containsAll(['GR 15 – stage-6', 'Étape du Grand Ballon 🥾']),
      );
      expect(await SqliteTrailRepository(upgraded).offlineCopies(), {
        'stage-6',
      });
      expect(await store.group('gr15'), isNull);
      await store.keepGroup(itinerary);
      expect((await store.group('gr15'))!.members, hasLength(4));
      await upgraded.close();
    });
  });

  group('walking stages', () {
    late Directory dir;
    late Database db;
    late StageTransport transport;
    late SqliteTrailRepository repository;
    late SqliteSharedTrailStore shared;
    late AppController app;

    late LiveGps gps;
    AppController controller({
      bool recording = false,
      AnnounceProgress? recap,
    }) => AppController(
      recap: recap,
      library: Library(repository, XmlGpxDecoder(), Elevation()),
      maps: Maps(),
      gps: Gps(),
      sync: Sync(),
      setAwake: (_) async {},
      vibrate: () async {},
      collaborative: CollaborativeTrails(
        shared,
        transport,
        repository,
        newId: const Uuid().v4,
        catalogue: transport,
      ),
      recorder: recording
          ? RecordWalk(MemoryRecording(), repository, gps, const Uuid().v4)
          : null,
    );

    /// Wait for the stages of the open trail, loaded in the background.
    Future<StageLinks> stages() async {
      for (var i = 0; i < 100; i++) {
        if (app.stagesOf(app.focused) case final links?) return links;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      throw StateError('stages not loaded');
    }

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dir = await Directory.systemTemp.createTemp('gpix-walk-stages');
      db = await openLocalDatabase('${dir.path}/library.db');
      repository = SqliteTrailRepository(db);
      shared = SqliteSharedTrailStore(db);
      transport = StageTransport();
      gps = LiveGps();
      for (final (i, t) in [stage5, stage6, stage7].indexed) {
        transport.full[t.id] = full(t);
        transport.details[t.id] = stageDetails(i + 1);
      }
      transport.groups['gr15'] = itinerary;
      app = controller();
      await app.reload();
    });
    tearDown(() async {
      app.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });

    test('jumping to the next stage keeps the walk in progress', () async {
      await app.openShared('stage-6');
      expect((await stages()).stage, 2);
      app.session!.active = true;
      final followed = app.selected;
      await app.openStage((await stages()).next!);
      expect(app.focused!.id, 'stage-7');
      expect(app.selected, same(followed), reason: 'the walk goes on');
      expect(app.session!.active, isTrue);
      expect((await stages()).previous!.trail!.id, 'stage-6');
    });

    test('the next stage stays in the itinerary walked, even when it is '
        'also a stage of another one', () async {
      transport.details['stage-7'] = stageDetails(
        3,
        also: [
          TrailGroupPath(const [tour], MemberRole.stage, stage: 6),
        ],
      );
      transport.groups['tour'] = TrailGroup(
        summary: tour,
        members: [
          for (var i = 1; i <= 5; i++)
            TrailGroupMember(
              MemberRole.stage,
              stage: i,
              trail: stageTrail(
                'tour-$i',
                north(46 + i / 100, 46.005 + i / 100),
              ),
            ),
          TrailGroupMember(MemberRole.stage, stage: 6, trail: stage7),
        ],
      );
      await app.openShared('stage-6');
      final links = await stages();
      await app.openStage(links.next!, from: links);
      final after = await stages();
      expect(app.focused!.id, 'stage-7');
      expect(after.group.id, 'gr15');
      expect(after.stage, 3);
      expect(after.previous!.trail!.id, 'stage-6');
    });

    test('offline, a walked stage still knows its neighbours', () async {
      await app.openShared('stage-6');
      await app.makeAvailableOffline(app.focused!);
      await stages();
      app.dispose();
      transport.online = false;
      app = controller();
      await app.reload();
      app.focus(app.trails.firstWhere((t) => t.id == 'stage-6'));
      expect((await stages()).next!.trail!.id, 'stage-7');
      await app.openStage((await stages()).next!);
      expect(
        (app.message as AppMessage).code,
        'stageUnavailable',
        reason: 'stage 7 was never downloaded',
      );
      expect((app.message as AppMessage).arguments, [3]);
    });

    test('at the end of a stage, its walk finishes by itself with a last '
        'summary, then the next stage continues from there', () async {
      app.dispose();
      final output = RecordingOutput();
      app = controller(recording: true, recap: AnnounceProgress(output));
      await app.initialize();
      await app.openShared('stage-6');
      await app.launch(app.focused!);
      await stages();
      expect(app.recorder!.active, isTrue);
      expect(app.atTrailEnd, isFalse);
      // Walked from the start of stage 6 to its north end.
      app.session!.startAlong = 0;
      gps.positions.add(Fix(const GeoPoint(45.0099, 6.0), 6, DateTime.now()));
      for (var i = 0; i < 100 && app.recorder!.current != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(app.recorder!.current, isNull, reason: 'finished by itself');
      await pumpEventQueue();
      final walks = (await repository.all()).where((t) => t.walk != null);
      final finished = walks.where((t) => t.walk!.ended != null).single;
      expect(finished.walk!.sourceTrailId, 'stage-6');
      expect((app.message as AppMessage).code, 'trailFinished');
      final last = output.recaps.single;
      expect(last.$1.finished, isTrue);
      expect(last.$1.remainingMetres, isNull);
      expect(last.$1.arrival, isNull);
      expect(last.$2, RecapItem.spokenByDefault);
      expect(output.cleared, 0, reason: 'the last summary stays');
      // History's "Continue from here" goes on with the next stage.
      final route = app.trails.firstWhere((t) => t.id == 'stage-6');
      await app.continueRoute(route, reversed: false);
      expect(app.selected!.id, 'stage-7');
      expect(app.session!.reverse, isTrue, reason: 'stage 7 is drawn north');
      app.stop();
      await app.recorder!.close();
    });

    test('continuing the next morning starts the next stage in the right '
        'direction', () async {
      await app.openShared('stage-6');
      await app.makeAvailableOffline(app.focused!);
      await stages();
      final route = app.trails.firstWhere((t) => t.id == 'stage-6');
      app.closeTrail();
      // Slept by the end of stage 6.
      app.mapFix = Fix(const GeoPoint(45.0099, 6.0003), 6, DateTime.now());
      await app.continueRoute(route, reversed: false);
      expect(app.selected!.id, 'stage-7');
      expect(app.session!.reverse, isTrue);
      expect(app.session!.active, isTrue);
      expect(app.trails.map((t) => t.id), contains('stage-7'));
      app.stop();
      // In the middle of stage 6, walked southwards yesterday.
      app.mapFix = Fix(const GeoPoint(45.005, 6.0), 6, DateTime.now());
      await app.continueRoute(route, reversed: true);
      expect(app.selected!.id, 'stage-6');
      expect(app.session!.reverse, isTrue);
      app.stop();
    });
  });

  group('stage views', () {
    Widget host(Widget child, Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    for (final (locale, previous, next) in [
      (const Locale('en'), 'Stage 1', 'Stage 3'),
      (const Locale('fr'), 'Étape 1', 'Étape 3'),
    ]) {
      testWidgets('previous and next stage buttons in ${locale.languageCode}', (
        tester,
      ) async {
        final app = AppController(
          library: Library(Repository(), XmlGpxDecoder(), Elevation()),
          maps: Maps(),
          gps: Gps(),
          sync: Sync(),
          setAwake: (_) async {},
          vibrate: () async {},
        );
        await tester.pumpWidget(
          host(
            StageNavigation(app, StageLinks.of(itinerary, 'stage-6')!),
            locale,
          ),
        );
        expect(find.text(previous), findsOneWidget);
        expect(find.text(next), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        app.dispose();
      });
    }
  });
}
