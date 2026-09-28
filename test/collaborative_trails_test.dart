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
import 'package:gpix/data/trail_identity_hash.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/shared_trails.dart';
import 'package:gpix/domain/sync.dart';
import 'package:gpix/presentation/localization.dart';
import 'package:gpix/presentation/trail_places.dart';
import 'package:gpix/presentation/trail_reviews.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'lifecycle_test.dart' show Maps, Gps, Elevation, Sync;

const identity = HashedTrailIdentity();

String gpx(String name, List<(double, double)> points) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
  <trk><name>$name</name><trkseg>
${points.map((p) => '    <trkpt lat="${p.$1}" lon="${p.$2}"><ele>812</ele></trkpt>').join('\n')}
  </trkseg></trk>
</gpx>''';

const ridge = [(45.2, 6.2), (45.2009, 6.2), (45.2018, 6.2011)];

SharedTrail sharedTrail(
  String id,
  String fingerprint, {
  String name = 'Crête partagée',
  int change = 1,
  int reviews = 0,
  double? average,
}) => SharedTrail(
  id: id,
  fingerprint: fingerprint,
  name: name,
  author: 'marie',
  metres: 212,
  outline: [
    [for (final p in ridge) GeoPoint(p.$1, p.$2)],
  ],
  change: change,
  reviews: reviews,
  average: average,
);

class FakeTransport implements SharedTrailTransport {
  List<SharedTrailPage> pages = [];
  final requested = <int>[];
  final full = <String, Trail>{};
  bool online = true;
  TrailReviews? current;
  (String, int, String)? reviewed;
  @override
  Future<SharedTrailPage> index(int since) async {
    if (!online) throw const SocketException('offline');
    requested.add(since);
    return pages.removeAt(0);
  }

  @override
  Future<Trail> download(String id) async {
    if (!online) throw const SocketException('offline');
    return full[id]!.withPublicId(id);
  }

  @override
  Future<TrailReviews> reviews(String id) async {
    if (!online) throw const SocketException('offline');
    return current!;
  }

  @override
  Future<TrailReviews> review(String id, int rating, String comment) async {
    reviewed = (id, rating, comment);
    return current = TrailReviews(
      trailId: id,
      count: 1,
      average: rating.toDouble(),
      canReview: true,
      reviews: [
        TrailReview(
          rating: rating,
          comment: comment,
          updatedAt: DateTime.utc(2026, 9, 28),
          mine: true,
          author: 'me',
        ),
      ],
    );
  }

  final serverPlaces = <String, TrailPlace>{};
  final sentPlaces = <String>[];
  var placeChange = 0;

  /// Status the server answers to the next place request, if any.
  int? placeFailure;
  TrailPlace _stored(TrailPlace p, {bool deleted = false}) =>
      serverPlaces[p.id] = TrailPlace(
        id: p.id,
        trailId: p.trailId,
        point: p.point,
        name: p.name,
        comment: p.comment,
        mine: true,
        author: 'me',
        updatedAt: DateTime.utc(2026, 9, 28),
        deleted: deleted,
        change: ++placeChange,
      );
  void _fail() {
    if (!online) throw const SocketException('offline');
    if (placeFailure case final status?) {
      throw RemoteFailure(status, const AppMessage('placeTooFar'));
    }
  }

  @override
  Future<TrailPlacePage> places(int since) async {
    if (!online) throw const SocketException('offline');
    final changed = [
      for (final p in serverPlaces.values)
        if (p.change > since) p,
    ]..sort((a, b) => a.change.compareTo(b.change));
    return TrailPlacePage(changed, changed.lastOrNull?.change ?? since, false);
  }

  @override
  Future<TrailPlace> savePlace(TrailPlace place) async {
    _fail();
    sentPlaces.add('save ${place.id} ${place.trailId}');
    return _stored(place);
  }

  @override
  Future<TrailPlace> removePlace(TrailPlace place) async {
    _fail();
    sentPlaces.add('delete ${place.id}');
    return _stored(place, deleted: true);
  }

  @override
  Future<TrailReviews> removeReview(String id) async => current = TrailReviews(
    trailId: id,
    count: 0,
    canReview: true,
    reviews: const [],
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late Database db;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gpix-shared');
    db = await openLocalDatabase('${dir.path}/library.db');
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  group('trail identity', () {
    test('matches the API fingerprint and identifier vector', () {
      // Same vector as the API test tests/public_trails.php.
      final vector = [
        [
          const GeoPoint(45.123456, 6.5, 1200),
          const GeoPoint(45.1235, 6.500051),
          const GeoPoint(45.1235, 6.500054),
          const GeoPoint(-0.000005, -179.999995),
        ],
        [const GeoPoint(1, 1)],
      ];
      final fingerprint = identity.fingerprint(vector)!;
      expect(
        fingerprint,
        'b351d3db9f7d047ab15da5fb8853642b0f9353144f33f425f3b1094cd0f01e64',
      );
      expect(
        identity.sharedId(fingerprint),
        '37d7df1a-08a1-57cd-a63d-50cefc8eb890',
      );
    });

    test('ignores elevation and sub-metre noise, not direction', () {
      final line = [for (final p in ridge) GeoPoint(p.$1, p.$2, 900)];
      final noisy = [for (final p in ridge) GeoPoint(p.$1 + 1e-7, p.$2 - 1e-7)];
      expect(identity.fingerprint([line]), identity.fingerprint([noisy]));
      expect(
        identity.fingerprint([line.reversed.toList()]),
        isNot(identity.fingerprint([line])),
      );
      expect(
        identity.fingerprint([
          [const GeoPoint(45, 6)],
        ]),
        isNull,
      );
    });
  });

  group('import', () {
    Library library(SqliteSharedTrailStore shared) => Library(
      SqliteTrailRepository(db),
      XmlGpxDecoder(),
      Elevation(),
      shared: shared,
      identity: identity,
    );

    test(
      'the same line imported again, even renamed, is not duplicated',
      () async {
        final shared = SqliteSharedTrailStore(db);
        final first = await library(shared)
            .import(gpx('Crête', ridge), 'a.gpx');
        final fingerprint = identity.fingerprint(first.trails.single.segments)!;
        expect(first.reused, 0);
        expect(first.trails.single.id, identity.sharedId(fingerprint));
        final again = await library(shared)
            .import(gpx('Crête renommée 🥾', ridge), 'b.gpx');
        expect(again.reused, 1);
        expect(again.trails.single.id, first.trails.single.id);
        expect(await SqliteTrailRepository(db).all(), hasLength(1));
      },
    );

    test('a line another walker shared reuses that trail', () async {
      final shared = SqliteSharedTrailStore(db);
      final line = [for (final p in ridge) GeoPoint(p.$1, p.$2)];
      await shared.apply(
        SharedTrailPage(
          [
            sharedTrail('legacy-id', identity.fingerprint([line])!),
          ],
          1,
          false,
        ),
      );
      final result = await library(shared)
          .import(gpx('My copy', ridge), 'c.gpx');
      expect(result.reused, 1);
      expect(result.trails.single.id, 'legacy-id');
      expect(result.trails.single.name, 'Crête partagée');
    });
  });

  group('local storage', () {
    test('upgrading a version 2 database keeps the library', () async {
      final path = '${dir.path}/v2.sqlite';
      final v2 = await openDatabase(
        path,
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE trails (id TEXT PRIMARY KEY, payload TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0, mutation TEXT NOT NULL)',
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
        },
      );
      final trail = Trail(
        id: 'kept',
        name: 'Été à Chamonix 🏔️',
        segments: [
          [for (final p in ridge) GeoPoint(p.$1, p.$2)],
        ],
        pois: const [],
      );
      await SqliteTrailRepository(v2).save(trail);
      await v2.insert('trail_statistics', {
        'trail_id': 'kept',
        'walks': 2,
        'metres': 400,
        'seconds': 300,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await v2.close();
      final upgraded = await openLocalDatabase(path);
      expect(await upgraded.getVersion(), 3);
      final restored = (await SqliteTrailRepository(upgraded).all()).single;
      expect(restored.name, 'Été à Chamonix 🏔️');
      expect(restored.publicId, isNull);
      expect(await SqliteSyncStore(upgraded).next(), isNotNull);
      expect(
        (await SqliteTrailStatisticsStore(upgraded).find('kept'))!.walks,
        2,
      );
      expect(await SqliteSharedTrailStore(upgraded).all(), isEmpty);
      await upgraded.close();
    });

    test('ACK and pull link a library trail to its shared trail', () async {
      final repository = SqliteTrailRepository(db);
      final store = SqliteSyncStore(db);
      final trail = Trail(
        id: 'mine',
        name: 'Mine',
        segments: [
          [const GeoPoint(0, 0), const GeoPoint(0, .01)],
        ],
        pois: const [],
      );
      await repository.save(trail);
      await store.acknowledge((await store.next())!, 1, publicId: 'shared');
      expect((await repository.all()).single.sharedId, 'shared');
      await store.merge([
        SyncOperation(
          'other',
          'op',
          4,
          false,
          Trail(
            id: 'other',
            name: 'Other phone',
            segments: trail.segments,
            pois: const [],
          ),
          publicId: 'public',
        ),
      ]);
      expect(
        (await repository.all()).firstWhere((t) => t.id == 'other').publicId,
        'public',
      );
    });

    test('a downloaded shared trail stays local until changed', () async {
      final repository = SqliteTrailRepository(db);
      final store = SqliteSyncStore(db);
      final trail = Trail(
        id: 'shared',
        name: 'Shared',
        segments: [
          [const GeoPoint(0, 0), const GeoPoint(0, .01)],
        ],
        pois: const [],
      ).withPublicId('shared');
      await repository.keep(trail);
      expect(await store.next(), isNull, reason: 'nothing to upload');
      expect((await repository.all()).single.publicId, 'shared');
      await repository.keep(trail.withDays(const []));
      expect(await repository.all(), hasLength(1));
      await repository.delete('shared');
      expect(await repository.all(), isEmpty);
      expect(await store.next(), isNull, reason: 'never in the account');
      await repository.save(trail);
      await store.acknowledge((await store.next())!, 1);
      await repository.delete('shared');
      await store.acknowledge((await store.next())!, 2);
      await repository.keep(trail);
      expect(await repository.all(), hasLength(1));
      expect(
        (await store.next())?.deleted,
        false,
        reason: 'reopening a deleted private copy restores it',
      );
    });
  });

  test(
    'catalogue refresh pages by change and resumes after a failure',
    () async {
      final shared = SqliteSharedTrailStore(db);
      final transport = FakeTransport()
        ..pages = [
          SharedTrailPage([sharedTrail('a', 'fa', change: 3)], 3, true),
          SharedTrailPage([sharedTrail('b', 'fb', change: 7)], 7, false),
        ];
      final sync = SynchronizeLibrary(
        SqliteSyncStore(db),
        _NoSync(),
        shared: (transport: transport, store: shared),
      );
      await sync.refreshShared();
      expect(transport.requested, [0, 3]);
      expect((await shared.all()).map((t) => t.id), ['a', 'b']);
      expect(await shared.cursor(), 7);
      transport.online = false;
      await sync.refreshShared();
      expect(await shared.all(), hasLength(2), reason: 'cache kept offline');
      transport
        ..online = true
        ..pages = [
          SharedTrailPage(
            [sharedTrail('a', 'fa', change: 9, reviews: 1, average: 4)],
            9,
            false,
          ),
        ];
      await sync.refreshShared();
      expect(transport.requested.last, 7);
      expect((await shared.all()).last.average, 4);
    },
  );

  test('catalogue JSON round-trips through the phone copy', () {
    final trail = sharedTrail('x', 'fx', reviews: 2, average: 3.5);
    final copy = SharedTrailCodec.decode(SharedTrailCodec.encode(trail));
    expect(copy.outline.single, hasLength(3));
    expect(copy.average, 3.5);
    expect(copy.author, 'marie');
  });

  group('map and reviews', () {
    late FakeTransport transport;
    late AppController app;
    late Trail full;
    setUp(() async {
      transport = FakeTransport();
      final shared = SqliteSharedTrailStore(db);
      final repository = SqliteTrailRepository(db);
      full = Trail(
        id: 'public',
        name: 'Crête partagée',
        segments: [
          [for (final p in ridge) GeoPoint(p.$1, p.$2, 800)],
        ],
        pois: const [],
      );
      transport.full['public'] = full;
      await shared.apply(
        SharedTrailPage(
          [
            sharedTrail('public', 'fp', reviews: 3, average: 4.3),
            sharedTrail('mine-public', 'fm', name: 'Duplicate of mine'),
          ],
          2,
          false,
        ),
      );
      await repository.save(
        Trail(
          id: 'mine',
          name: 'Mine',
          segments: [
            [const GeoPoint(0, 0), const GeoPoint(0, .01)],
          ],
          pois: const [],
        ),
      );
      await SqliteSyncStore(db).acknowledge(
        (await SqliteSyncStore(db).next())!,
        1,
        publicId: 'mine-public',
      );
      app = AppController(
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
        ),
      );
      await app.reload();
    });
    tearDown(() => app.dispose());

    test('every shared trail is pinned once, beside the library', () {
      expect(app.pinned.map((t) => t.id), ['mine', 'public']);
      expect(app.isPreview(app.pinned.last), isTrue);
      expect(app.sharedFor(app.pinned.first)!.name, 'Duplicate of mine');
    });

    test('opening a shared trail downloads it once for offline use', () async {
      transport.current = const TrailReviews(
        trailId: 'public',
        count: 0,
        reviews: [],
        canReview: false,
        completion: .42,
      );
      await app.open(app.pinned.last);
      expect(app.focused!.id, 'public');
      expect(app.focused!.segments.single.first.elevation, 800);
      expect(app.isPreview(app.focused!), isFalse);
      expect(app.pinned.map((t) => t.id), ['public', 'mine']);
      await app.refreshReviews();
      expect(app.reviews!.completion, .42);
      transport.online = false;
      await app.reload();
      expect(app.trails.map((t) => t.id), contains('public'));
      await app.refreshReviews();
      expect(app.reviews!.cached, isTrue, reason: 'last copy shown offline');
    });

    test('offline, an undownloaded shared trail reports it honestly', () async {
      transport.online = false;
      await app.open(app.pinned.last);
      expect(app.focused, isNull);
      expect(
        (app.message as MessageFailure).detail.code,
        'sharedTrailUnavailable',
      );
    });

    test('a review is published after pushing pending walks', () async {
      transport.current = const TrailReviews(
        trailId: 'public',
        count: 0,
        reviews: [],
        canReview: true,
      );
      await app.open(app.pinned.last);
      await app.refreshReviews();
      await app.saveReview(5, '  Superbe lever de soleil 🌄 ');
      expect(transport.reviewed, ('public', 5, 'Superbe lever de soleil 🌄'));
      expect(app.reviews!.mine!.rating, 5);
      expect(app.message, AppMessage.reviewSaved);
      await app.deleteReview();
      expect(app.reviews!.mine, isNull);
    });

    Fix fixAt(double lat, double lon) =>
        Fix(GeoPoint(lat, lon, 1650), 6, DateTime.now());
    SynchronizeLibrary syncing() => SynchronizeLibrary(
      SqliteSyncStore(db),
      _NoSync(),
      shared: (transport: transport, store: SqliteSharedTrailStore(db)),
    );

    test(
      'a walker adds a named place where they stand, even offline',
      () async {
        transport.current = const TrailReviews(
          trailId: 'public',
          count: 0,
          reviews: [],
          canReview: false,
        );
        await app.open(app.pinned.last);
        final trail = app.focused!;
        app.mapFix = fixAt(45.2004, 6.21);
        await app.addPlace(trail, 'Trop loin', '');
        expect(
          (app.message as MessageFailure).detail.code,
          'placeTooFar',
          reason: 'more than 100 m from the line',
        );
        expect(app.places, isEmpty);

        transport.online = false;
        app.mapFix = fixAt(45.2004, 6.2003);
        await app.addPlace(trail, '  Belle vue 🏔️ ', 'Au lever du soleil');
        expect(app.message, AppMessage.placeSaved);
        final place = app.places.single;
        expect(place.name, 'Belle vue 🏔️');
        expect(place.point.lat, 45.2004, reason: 'the real position');
        expect(place.pending, isTrue);
        expect(place.trailId, 'public');
        expect(app.pois.map((p) => p.name), contains('Belle vue 🏔️'));

        await syncing().refreshShared();
        expect(transport.sentPlaces, isEmpty);
        expect(
          (await SqliteSharedTrailStore(db).places()).single.pending,
          true,
        );

        transport.online = true;
        await syncing().refreshShared();
        expect(transport.sentPlaces, ['save ${place.id} public']);
        final shared = (await SqliteSharedTrailStore(db).places()).single;
        expect(shared.pending, isFalse);
        expect(shared.author, 'me');

        await app.editPlace(shared, 'Belvédère', '');
        await app.deletePlace(app.places.single);
        expect(app.places, isEmpty, reason: 'hidden until the server confirms');
        await syncing().refreshShared();
        expect(transport.sentPlaces.last, 'delete ${place.id}');
        expect(await SqliteSharedTrailStore(db).places(), isEmpty);
      },
    );

    test('an unsent place is deleted without any request', () async {
      await app.open(app.pinned.last);
      app.mapFix = fixAt(45.2004, 6.2003);
      transport.online = false;
      await app.addPlace(app.focused!, 'Source', '');
      await app.deletePlace(app.places.single);
      transport.online = true;
      await syncing().refreshShared();
      expect(transport.sentPlaces, isEmpty);
    });

    test(
      'places wait for their trail to be shared, refusals are dropped',
      () async {
        final store = SqliteSharedTrailStore(db);
        TrailPlace place(String id, String trail) => TrailPlace(
          id: id,
          trailId: trail,
          point: const GeoPoint(0, .005),
          name: id,
          mine: true,
          updatedAt: DateTime.utc(2026, 9, 28),
        );
        // A trail imported offline, later linked to the line someone shared.
        await store.savePlace(place('waiting', 'mine'));
        transport.placeFailure = 404;
        await syncing().refreshShared();
        expect(await store.pendingPlaces(), hasLength(1));
        expect(
          (await store.pendingPlaces()).single.place.trailId,
          'mine-public',
          reason: 'resolved through the library link',
        );
        transport.placeFailure = 422;
        await syncing().refreshShared();
        expect(await store.pendingPlaces(), isEmpty);
      },
    );

    test(
      'other walkers\' places arrive offline and leave with their deletion',
      () async {
        final store = SqliteSharedTrailStore(db);
        final theirs = TrailPlace(
          id: 'theirs',
          trailId: 'mine-public',
          point: const GeoPoint(0, .005),
          name: 'Cascade',
          comment: 'Belle après la pluie',
          author: 'marie',
          mine: false,
          updatedAt: DateTime.utc(2026, 9, 27),
          change: 5,
        );
        await store.applyPlaces(TrailPlacePage([theirs], 5, false));
        await app.reload();
        expect(app.visiblePlaces.single.author, 'marie');
        expect(await store.placeCursor(), 5);
        await store.applyPlaces(
          TrailPlacePage(
            [
              TrailPlace(
                id: 'theirs',
                trailId: 'mine-public',
                point: theirs.point,
                name: theirs.name,
                mine: false,
                updatedAt: DateTime.utc(2026, 9, 28),
                deleted: true,
                change: 6,
              ),
            ],
            6,
            false,
          ),
        );
        expect(await store.places(), isEmpty);
      },
    );

    for (final (language, write, required) in [
      ('en', 'Give my review', 'Walk the whole trail once'),
      ('fr', 'Donner mon avis', 'Parcourez une fois tout le sentier'),
    ]) {
      testWidgets('the panel shows reviews and who may write ($language)', (
        tester,
      ) async {
        Future<void> show(TrailReviews reviews) async {
          app.reviews = reviews;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListView(children: [TrailReviewsSection(app, full)]),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(
          TrailReviews(
            trailId: 'public',
            count: 1,
            average: 4,
            canReview: false,
            completion: .5,
            reviews: [
              TrailReview(
                author: 'marie',
                rating: 4,
                comment: 'Très beau',
                updatedAt: DateTime.utc(2026, 9, 1),
                mine: false,
              ),
            ],
          ),
        );
        expect(find.textContaining(required), findsOneWidget);
        expect(find.textContaining('50'), findsOneWidget);
        expect(find.text('Très beau'), findsOneWidget);
        expect(find.textContaining('marie'), findsWidgets);
        expect(find.text(write), findsNothing);
        await show(
          const TrailReviews(
            trailId: 'public',
            count: 0,
            canReview: true,
            reviews: [],
          ),
        );
        expect(find.text(write), findsOneWidget);
        await tester.tap(find.text(write));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewDialog), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a place needs a name; its author may edit or delete it', (
      tester,
    ) async {
      Widget page(Widget child) => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Builder(builder: (context) => child)),
      );
      await tester.pumpWidget(page(const PlaceDialog()));
      final save = find.widgetWithText(FilledButton, 'Enregistrer');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'Belle vue');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      TrailPlace place({required bool mine}) => TrailPlace(
        id: 'p',
        trailId: 'public',
        point: const GeoPoint(45.2004, 6.2003),
        name: 'Cascade',
        comment: 'Belle après la pluie',
        author: 'marie',
        mine: mine,
        updatedAt: DateTime.utc(2026, 9, 28),
      );
      for (final mine in [false, true]) {
        await tester.pumpWidget(
          page(
            Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTrailPlace(context, app, place(mine: mine)),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Belle après la pluie'), findsOneWidget);
        expect(
          find.textContaining(mine ? 'Ajouté par Vous' : 'Ajouté par marie'),
          findsOneWidget,
        );
        expect(find.text('Modifier'), mine ? findsOneWidget : findsNothing);
        expect(find.text('Supprimer'), mine ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class _NoSync implements SyncTransport {
  @override
  Future<SyncResult> push(SyncOperation operation) async =>
      const SyncResult(1, false);
  @override
  Future<List<SyncOperation>> pull() async => [];
}
