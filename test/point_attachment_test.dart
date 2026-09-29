import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/collaborative_trails.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/shared_trail_codec.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/point_attachment.dart';
import 'package:gpix/domain/ports.dart';
import 'package:gpix/domain/shared_trails.dart';
import 'package:gpix/domain/sync.dart';
import 'package:gpix/presentation/app.dart';
import 'package:gpix/presentation/localization.dart';
import 'package:gpix/presentation/trail_places.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'collaborative_trails_test.dart' show FakeTransport, gpx, sharedTrail;
import 'lifecycle_test.dart' show Maps, Gps, Elevation, Sync;

/// A GPX file holding only waypoints: (lat, lon, name, description).
String waypoints(List<(double, double, String, String)> points) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
${points.map((p) => '  <wpt lat="${p.$1}" lon="${p.$2}"><name>${p.$3}</name><desc>${p.$4}</desc></wpt>').join('\n')}
</gpx>''';

/// About 2.2 km heading north.
const camino = [(45.20, 6.20), (45.21, 6.20), (45.22, 6.20)];

Trail track(String id, List<(double, double)> points) => Trail(
  id: id,
  name: id,
  segments: [
    [for (final p in points) GeoPoint(p.$1, p.$2)],
  ],
  pois: const [],
);

Trail pointsFile(String id, List<Poi> pois) =>
    Trail(id: id, name: id, segments: const [], pois: pois);

Poi poi(double lat, double lon, String name, [String description = '']) =>
    Poi(GeoPoint(lat, lon), name, description);

final hostels = [
  poi(45.205, 6.2005, 'Fontaine', 'Eau potable'),
  // About 2 km east of the line: a hostel in the village.
  poi(45.215, 6.225, 'Gîte d’étape « Le Refuge »', '12 places'),
  // About 6 km east: out of reach.
  poi(45.215, 6.28, 'Château lointain'),
  poi(45.212, 6.2003, '', 'Source\nÀ droite du chemin'),
  poi(45.213, 6.2003, '', ''),
  // About 11 m from the hostel, spelt differently: the same place.
  poi(45.2151, 6.225, "GITE D'ETAPE le refuge"),
  poi(45.21805, 6.2002, 'belvédère !'),
];

TrailPlace place(
  String id,
  String trailId,
  GeoPoint point,
  String name, {
  bool mine = false,
}) => TrailPlace(
  id: id,
  trailId: trailId,
  point: point,
  name: name,
  mine: mine,
  author: mine ? 'me' : 'marie',
  updatedAt: DateTime.utc(2026, 9, 28),
  change: mine ? 0 : 1,
);

/// A server that already has the hostel: a new copy of it is the existing one.
class DedupTransport extends FakeTransport {
  final origins = <String, PlaceOrigin>{};
  @override
  Future<TrailPlace> savePlace(TrailPlace place) async {
    origins[place.name] = place.origin;
    for (final existing in serverPlaces.values) {
      if (placeNameKey(existing.name) == placeNameKey(place.name) &&
          distance(existing.point, place.point) <= duplicatePlaceDistance) {
        return existing;
      }
    }
    return super.savePlace(place);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('planning an attachment', () {
    final trail = track('camino', camino);
    final belvedere = place(
      'belvedere',
      'camino',
      const GeoPoint(45.218, 6.2002),
      'Belvédère',
    );

    test('points become places of the trail, the others stay', () {
      final file = pointsFile('hostels', hostels);
      final plan = PointAttachment.plan([file], [trail], [belvedere]);
      String? fate(String name) =>
          plan.points.where((p) => p.name == name).firstOrNull?.fate.name;
      expect(fate('Fontaine'), 'added');
      expect(fate('Gîte d’étape « Le Refuge »'), 'added', reason: '2 km off');
      expect(
        plan.points.firstWhere((p) => p.poi.name == 'Château lointain').fate,
        PointFate.tooFar,
      );
      final source = plan.points.firstWhere((p) => p.name == 'Source');
      expect(source.fate, PointFate.added);
      expect(source.comment, '', reason: 'named from its description');
      expect(fate("GITE D'ETAPE le refuge"), 'known', reason: 'same batch');
      expect(fate('belvédère !'), 'known', reason: 'already on the trail');
      expect(plan.count(PointFate.added), 3);
      expect(plan.count(PointFate.known), 2);
      expect(plan.count(PointFate.tooFar), 1);
      expect(plan.count(PointFate.unnamed), 1);
      expect(plan.attachesAny, isTrue);
      expect(
        plan.points.firstWhere((p) => p.name == 'Fontaine').comment,
        'Eau potable',
      );

      // Nothing is lost: what is not attached stays in the file.
      expect(plan.emptied, isEmpty);
      expect(plan.remaining.single.id, 'hostels');
      expect(plan.remaining.single.pois.map((p) => p.name), [
        'Château lointain',
        '',
      ]);
    });

    test('a file entirely attached leaves the library', () {
      final plan = PointAttachment.plan(
        [
          pointsFile('near', [poi(45.205, 6.2005, 'Fontaine')]),
        ],
        [trail],
        const [],
      );
      expect(plan.emptied, ['near']);
      expect(plan.remaining, isEmpty);
    });

    test('each point goes to the nearest trail', () {
      final east = track('east', [(45.20, 6.30), (45.22, 6.30)]);
      final plan = PointAttachment.plan(
        [pointsFile('hostels', hostels)],
        [trail, east],
        const [],
      );
      final castle = plan.points.firstWhere(
        (p) => p.poi.name == 'Château lointain',
      );
      expect(castle.fate, PointFate.added);
      expect(castle.trail?.id, 'east');
      expect(
        plan.points.firstWhere((p) => p.name == 'Fontaine').trail?.id,
        'camino',
      );
    });

    test('places of other trails and deleted places do not count', () {
      final plan = PointAttachment.plan(
        [
          pointsFile('f', [poi(45.218, 6.2002, 'Belvédère')]),
        ],
        [trail],
        [
          place('a', 'elsewhere', const GeoPoint(45.218, 6.2002), 'Belvédère'),
          TrailPlace(
            id: 'b',
            trailId: 'camino',
            point: const GeoPoint(45.218, 6.2002),
            name: 'Belvédère',
            mine: false,
            deleted: true,
            updatedAt: DateTime.utc(2026, 9, 28),
          ),
        ],
      );
      expect(plan.count(PointFate.added), 1);
    });

    test('names are compared without case, accents or punctuation', () {
      expect(placeNameKey('Gîte d’étape « Le Refuge »'), 'gitedetapelerefuge');
      expect(placeNameKey("GITE D'ETAPE le refuge"), 'gitedetapelerefuge');
      expect(placeNameKey('Œuvre'), placeNameKey('oeuvre'));
      expect(placeNameKey('東京 駅'), '東京駅', reason: 'other scripts kept');
      expect(placeNameKey(' 🥾 '), '🥾', reason: 'emoji compared as written');
      expect(placeNameKey('🥾'), isNot(placeNameKey('⛲')));
    });

    test('long names and descriptions are cut to the API limits', () {
      final plan = PointAttachment.plan(
        [
          pointsFile('f', [poi(45.205, 6.2005, '🥾' * 250, 'é' * 2100)]),
        ],
        [trail],
        const [],
      );
      final point = plan.points.single;
      expect(point.name.runes.length, maximumPlaceNameLength);
      expect(point.comment.runes.length, maximumReviewLength);
    });

    test('points within reach rank the trails', () {
      final points = [for (final p in hostels) p.point];
      expect(pointsInRange(points, trail), 6);
      expect(
        pointsInRange(points, track('far', [(46.0, 7.0), (46.1, 7.0)])),
        0,
      );
      expect(pointsInRange(points, pointsFile('f', hostels)), 0);
    });
  });

  group('stored and synced', () {
    late Directory dir;
    late Database db;
    late SqliteSharedTrailStore store;
    late SqliteTrailRepository repository;
    late CollaborativeTrails collaborative;
    late DedupTransport transport;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('gpix-attach');
      db = await openLocalDatabase('${dir.path}/library.db');
      store = SqliteSharedTrailStore(db);
      repository = SqliteTrailRepository(db);
      transport = DedupTransport();
      collaborative = CollaborativeTrails(
        store,
        transport,
        repository,
        newId: const Uuid().v4,
      );
    });
    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    Future<int> outbox() async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM outbox')).first['n']
            as int;

    test(
      'places and their files change in one transaction, undo included',
      () async {
        final camino_ = track('camino', camino);
        final hostelFile = pointsFile('hostels', hostels);
        final spring = pointsFile('spring', [poi(45.205, 6.2005, 'Source ⛲')]);
        for (final t in [camino_, hostelFile, spring]) {
          await repository.save(t);
        }
        final queued = await outbox();
        final plan = PointAttachment.plan(
          [hostelFile, spring],
          [camino_],
          const [],
        );
        final attached = await collaborative.attachPoints(plan);

        final places = await store.places();
        expect(places, hasLength(5));
        expect(places.every((p) => p.origin == PlaceOrigin.imported), isTrue);
        expect(places.every((p) => p.pending && p.mine), isTrue);
        expect(places.map((p) => p.trailId).toSet(), {'camino'});
        expect(
          places.map((p) => p.name),
          contains('Gîte d’étape « Le Refuge »'),
        );
        expect((await repository.find('hostels'))!.pois.map((p) => p.name), [
          'Château lointain',
          '',
        ], reason: 'the points left out stay in the file');
        expect(await repository.find('spring'), isNull, reason: 'emptied');
        expect(await outbox(), queued + 2, reason: 'both files sync');

        await collaborative.detachPoints(attached);
        expect(await store.places(), isEmpty);
        expect(await store.pendingPlaces(), isEmpty, reason: 'never sent');
        expect((await repository.find('hostels'))!.pois, hasLength(7));
        expect((await repository.find('spring'))!.pois.single.name, 'Source ⛲');
      },
    );

    test(
      'sync sends the origin and keeps the server\'s existing copy',
      () async {
        final hostel = TrailPlace(
          id: 'server-hostel',
          trailId: 'camino',
          point: const GeoPoint(45.215, 6.225),
          name: 'Gîte d’étape « Le Refuge »',
          comment: '12 places',
          mine: false,
          author: 'marie',
          updatedAt: DateTime.utc(2026, 9, 27),
          change: 1,
          origin: PlaceOrigin.imported,
        );
        transport.serverPlaces['server-hostel'] = hostel;
        transport.placeChange = 1;
        await repository.save(track('camino', camino));
        await collaborative.attachPoints(
          PointAttachment.plan(
            [
              pointsFile('f', [
                poi(45.2151, 6.225, "GITE D'ETAPE le refuge"),
                poi(45.205, 6.2005, 'Fontaine'),
              ]),
            ],
            [track('camino', camino)],
            const [],
          ),
        );
        await SynchronizeLibrary(
          SqliteSyncStore(db),
          _NoSync(),
          shared: (transport: transport, store: store),
        ).refreshShared();
        expect(transport.origins.values.toSet(), {PlaceOrigin.imported});
        expect(await store.pendingPlaces(), isEmpty);
        final places = await store.places();
        expect(places.map((p) => p.id), containsAll(['server-hostel']));
        expect(places, hasLength(2), reason: 'no second copy of the hostel');
        expect(
          places.firstWhere((p) => p.id == 'server-hostel').comment,
          '12 places',
        );
      },
    );

    test('places stored before origins existed were added on site', () {
      final legacy = SharedTrailCodec.decodePlace({
        'id': 'p',
        'trailId': 't',
        'lat': 45.0,
        'lon': 6.0,
        'elevation': null,
        'name': 'Cascade',
        'comment': '',
        'author': 'marie',
        'mine': false,
        'deleted': false,
        'updatedAt': '2026-09-01T10:00:00Z',
        'change': 3,
      });
      expect(legacy.origin, PlaceOrigin.onSite);
      final imported = TrailPlace(
        id: 'i',
        trailId: 't',
        point: const GeoPoint(45, 6),
        name: 'Gîte',
        mine: true,
        updatedAt: DateTime.utc(2026, 9, 28),
        origin: PlaceOrigin.imported,
      );
      final decoded = SharedTrailCodec.decodePlace(
        SharedTrailCodec.encodePlace(imported),
      );
      expect(decoded.origin, PlaceOrigin.imported);
      expect(
        decoded.edited('Refuge', '', DateTime.utc(2026)).origin,
        PlaceOrigin.imported,
      );
    });
  });

  group('attaching from the app', () {
    late Directory dir;
    late Database db;
    late FakeTransport transport;
    late AppController app;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('gpix-attach-app');
      db = await openLocalDatabase('${dir.path}/library.db');
      transport = FakeTransport();
      final repository = SqliteTrailRepository(db);
      app = AppController(
        library: Library(repository, XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: Gps(),
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
        collaborative: CollaborativeTrails(
          SqliteSharedTrailStore(db),
          transport,
          repository,
          newId: const Uuid().v4,
          catalogue: transport,
        ),
      );
      await app.reload();
    });
    tearDown(() async {
      app.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });

    test(
      'files imported together are attached to their track, then undone',
      () async {
        await app.importFiles([
          (gpx('Chemin du Puy', camino), 'Chemin du Puy'),
          (
            waypoints([
              for (final p in hostels)
                (p.point.lat, p.point.lon, p.name, p.description),
            ]),
            'Hébergements',
          ),
        ]);
        final plan = app.attaching!;
        expect(plan.targets.single.name, 'Chemin du Puy');
        expect(plan.sources.single.pois, hasLength(7));
        expect(app.focused?.name, 'Chemin du Puy', reason: 'previewed on it');
        expect(app.pointsFiles, hasLength(1));

        await app.confirmAttachment();
        expect(app.attaching, isNull);
        expect(app.message, isA<AppMessage>());
        expect((app.message as AppMessage).code, 'pointsAttached');
        expect((app.message as AppMessage).arguments, [4, 1, 2]);
        final trail = app.trails.firstWhere((t) => t.followable);
        expect(app.placeCount(trail), 4);
        expect(
          app.visiblePlaces.map((p) => p.name),
          contains('Gîte d’étape « Le Refuge »'),
        );
        expect(app.pointsFiles.single.pois, hasLength(2));

        await app.undoAttachment();
        expect(app.message, AppMessage.attachmentUndone);
        expect(app.places, isEmpty);
        expect(app.pointsFiles.single.pois, hasLength(7));
        expect(app.lastAttachment, isNull);
      },
    );

    test(
      'a library file goes to the best trail, from the catalogue too',
      () async {
        await app.importFiles([
          (waypoints([(45.2004, 6.2003, 'Cascade', '')]), 'Cascades'),
        ]);
        expect(app.attaching, isNull, reason: 'no trail within reach yet');
        expect(app.pointsFiles, hasLength(1));
        await app.beginAttachment(app.pointsFiles);
        expect(app.message, AppMessage.noTrailNearPoints);

        transport.areaTrails = [sharedTrail('public')];
        transport.full['public'] = Trail(
          id: 'public',
          name: 'Crête partagée',
          segments: [
            [
              const GeoPoint(45.2, 6.2, 800),
              const GeoPoint(45.2009, 6.2, 800),
              const GeoPoint(45.2018, 6.2011, 800),
            ],
          ],
          pois: const [],
        );
        await app.beginAttachment(app.pointsFiles);
        expect(app.attachTargets.single.catalogue, isTrue);
        expect(
          app.attaching!.targets.single.segments.single,
          hasLength(3),
          reason: 'the whole line was downloaded',
        );
        await app.confirmAttachment();
        expect(app.places.single.trailId, 'public');
        expect(app.places.single.origin, PlaceOrigin.imported);
        expect(app.pointsFiles, isEmpty);
      },
    );

    test('points only show with the trail that is open', () async {
      await app.importFiles([
        (gpx('Chemin du Puy', camino), 'Chemin du Puy'),
        (
          waypoints([
            (45.205, 6.2005, 'Fontaine', ''),
            (45.215, 6.28, 'Château lointain', ''),
          ]),
          'Hébergements',
        ),
      ]);
      await app.confirmAttachment();
      final trail = app.trails.firstWhere((t) => t.followable);
      final file = app.pointsFiles.single;

      app.closeTrail();
      expect(app.pois, isEmpty, reason: 'no trail selected');
      expect(app.visiblePlaces, isEmpty);

      app.focus(trail);
      expect(app.pois.map((p) => p.name), ['Fontaine']);
      expect(app.visiblePlaces.single.name, 'Fontaine');

      app.focus(file);
      expect(app.pois.map((p) => p.name), [
        'Château lointain',
      ], reason: 'a points file shows its own points once opened');
    });

    test('a track imported far from the points is not proposed', () async {
      await app.importFiles([(gpx('Chemin du Puy', camino), 'Chemin du Puy')]);
      await app.importFiles([
        (gpx('Ailleurs', [(46.0, 7.0), (46.01, 7.0)]), 'Ailleurs'),
        (waypoints([(45.205, 6.2005, 'Fontaine', '')]), 'Fontaines'),
      ]);
      expect(app.attaching!.targets.single.name, 'Chemin du Puy');
      expect(app.attaching!.count(PointFate.added), 1);
    });

    test('the walker may choose another trail or cancel', () async {
      await app.importFiles([
        (gpx('Chemin du Puy', camino), 'Chemin du Puy'),
        (gpx('Variante', [(45.20, 6.21), (45.22, 6.21)]), 'Variante'),
      ]);
      await app.importFiles([
        (waypoints([(45.21, 6.2105, 'Pont', '')]), 'Ponts'),
      ]);
      expect(
        app.attaching!.targets.single.name,
        'Variante',
        reason: 'the point is closer to it',
      );
      expect(app.attachTargets.map((t) => t.trail.name).toSet(), {
        'Chemin du Puy',
        'Variante',
      });
      await app.chooseAttachTarget(
        app.attachTargets.firstWhere((t) => t.trail.name == 'Chemin du Puy'),
      );
      expect(app.attaching!.targets.single.name, 'Chemin du Puy');
      app.cancelAttachment();
      expect(app.attaching, isNull);
      expect(app.places, isEmpty);
      expect(app.pointsFiles, hasLength(1));
    });
  });

  for (final (language, title, added, known, far, attach, share) in [
    (
      'en',
      'Attach points to a trail',
      '4 new places',
      '1 point already on the trail',
      '1 point more than 5 km away stays in the file',
      'Attach',
      'These places will be visible to every walker. I confirm I may share them.',
    ),
    (
      'fr',
      'Rattacher des points à un parcours',
      '4 nouveaux lieux',
      '1 point déjà présent sur le parcours',
      '1 point à plus de 5 km reste dans le fichier',
      'Rattacher',
      'Ces lieux seront visibles par tous les marcheurs. Je confirme pouvoir les partager.',
    ),
  ]) {
    testWidgets('the preview explains the attachment ($language)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('gpix-attach-ui');
      final db = await tester.runAsync(
        () => openLocalDatabase('${dir.path}/library.db'),
      );
      final repository = SqliteTrailRepository(db!);
      final app = AppController(
        library: Library(repository, XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: Gps(),
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
        collaborative: CollaborativeTrails(
          SqliteSharedTrailStore(db),
          FakeTransport(),
          repository,
          newId: const Uuid().v4,
        ),
      );
      await tester.runAsync(() async {
        await repository.save(track('camino', camino));
        await repository.save(pointsFile('Hébergements', hostels));
        await app.reload();
      });

      // The library tells about the file not attached to any trail.
      await tester.pumpWidget(
        LocalizedApp(
          controller: LocaleController(initialLocale: Locale(language)),
          homeBuilder: (_) => Home(
            app,
            mapBuilder: (_) => const ColoredBox(color: Colors.green),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(language == 'fr' ? 'Mes parcours' : 'My trails'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          language == 'fr'
              ? '1 fichier de points n’est rattaché à aucun parcours'
              : '1 points file is not attached to a trail',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          language == 'fr'
              ? 'Non rattaché à un parcours'
              : 'Not attached to a trail',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.text(language == 'fr' ? 'Les afficher' : 'Show them'),
      );
      await tester.pumpAndSettle();
      expect(find.text('camino'), findsNothing, reason: 'only points files');

      await tester.runAsync(() => app.beginAttachment(app.pointsFiles));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(
          language == 'fr' ? 'Retour à la carte' : 'Back to the map',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text(added), findsOneWidget);
      expect(find.text(known), findsOneWidget, reason: 'the hostel twice');
      await tester.drag(find.text(title), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text(far), findsOneWidget);
      final button = find.ancestor(
        of: find.text(attach),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      await tester.ensureVisible(button);
      expect(
        tester.widget<FilledButton>(button).onPressed,
        isNull,
        reason: 'sharing must be confirmed first',
      );
      await tester.tap(find.text(share));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await tester.runAsync(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
    });

    testWidgets('a place tells how it came onto the trail ($language)', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final app = AppController(
        library: Library(_NoRepository(), XmlGpxDecoder(), Elevation()),
        maps: Maps(),
        gps: Gps(),
        sync: Sync(),
        setAwake: (_) async {},
        vibrate: () async {},
      );
      for (final (origin, label) in [
        (
          PlaceOrigin.onSite,
          language == 'fr' ? 'Vu sur place' : 'Seen on site',
        ),
        (
          PlaceOrigin.imported,
          language == 'fr'
              ? 'Importé d’un fichier GPX'
              : 'Imported from a GPX file',
        ),
      ]) {
        showTrailPlace(
          context,
          app,
          TrailPlace(
            id: 'p',
            trailId: 't',
            point: const GeoPoint(45, 6),
            name: 'Gîte',
            mine: false,
            author: 'marie',
            updatedAt: DateTime.utc(2026, 9, 28),
            origin: origin,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
      }
      app.dispose();
    });
  }
}

class _NoSync implements SyncTransport {
  @override
  Future<SyncResult> push(SyncOperation operation) async =>
      const SyncResult(1, false);
  @override
  Future<List<SyncOperation>> pull() async => [];
}

class _NoRepository implements TrailRepository {
  @override
  Future<List<Trail>> all() async => [];
  @override
  Future<void> delete(String id) async {}
  @override
  Future<Trail?> find(String id) async => null;
  @override
  Future<void> keep(Trail trail) async {}
  @override
  Future<Set<String>> offlineCopies() async => {};
  @override
  Future<void> save(Trail trail) async {}
}
