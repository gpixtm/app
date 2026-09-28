import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/collaborative_trails.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:gpix/data/catalogue_codec.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/data/trail_identity_hash.dart';
import 'package:gpix/domain/catalogue.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/shared_trails.dart';
import 'package:gpix/domain/sync.dart';
import 'package:gpix/presentation/localization.dart';
import 'package:gpix/presentation/trail_details.dart';
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
  String id, {
  String name = 'Crête partagée',
  int reviews = 0,
  double? average,
  String source = 'osm',
}) => SharedTrail(
  id: id,
  name: name,
  author: source == walkerSource ? 'marie' : null,
  metres: 212,
  outline: [
    [for (final p in ridge) GeoPoint(p.$1, p.$2)],
  ],
  reviews: reviews,
  average: average,
  source: source,
  ref: 'GR 65',
);

const podiensis = TrailGroupSummary(
  id: 'podiensis',
  kind: TrailGroupKind.itinerary,
  name: 'Via Podiensis',
  metres: 740000,
  trailCount: 30,
  source: 'osm',
  ref: 'GR 65',
);
const stJames = TrailGroupSummary(
  id: 'st-james',
  kind: TrailGroupKind.collection,
  name: 'Ways of St James',
  metres: 3000000,
  trailCount: 120,
  source: walkerSource,
  editorial: 'st-james',
);

const publicDetails = TrailDetails(
  source: 'osm',
  licence: 'ODbL-1.0',
  attribution: '© OpenStreetMap contributors',
  fields: {
    'ref': 'GR 65',
    'marking': 'red:white:red_bar',
    'from': 'Le Puy',
    'to': 'Saugues',
  },
  descriptions: {
    'fr': 'Première étape vers Compostelle',
    'en': 'First stage to Santiago',
  },
  osmType: 'relation',
  osmId: 300,
  reviews: 3,
  average: 4.3,
  paths: [
    TrailGroupPath([stJames, podiensis], MemberRole.stage, stage: 1),
  ],
);

class FakeTransport implements SharedTrailTransport, CatalogueTransport {
  List<SharedTrail> areaTrails = [];
  final requestedAreas = <Bounds>[];
  final full = <String, Trail>{};
  final groups = <String, TrailGroup>{};
  final saved = <String, GroupDraft>{};
  bool online = true;
  TrailReviews? current;
  (String, int, String)? reviewed;

  void _online() {
    if (!online) throw const SocketException('offline');
  }

  @override
  Future<CatalogueArea> area(Bounds view, {int limit = 300}) async {
    _online();
    requestedAreas.add(view);
    return CatalogueArea(areaTrails, false);
  }

  @override
  Future<CataloguePage> search(String query, {String? cursor}) async {
    _online();
    return CataloguePage([
      const CatalogueGroupItem(stJames),
      for (final t in areaTrails) CatalogueTrailItem(t),
    ], null);
  }

  @override
  Future<CatalogueTrail> trail(String id) async {
    _online();
    final trail = full[id];
    if (trail == null) throw RemoteFailure(404, const AppMessage('x'));
    return CatalogueTrail(trail.withPublicId(id), publicDetails);
  }

  @override
  Future<TrailGroup> group(String id) async {
    _online();
    return groups[id]!;
  }

  @override
  Future<List<TrailGroupSummary>> myGroups() async => [
    for (final g in groups.values)
      if (g.summary.mine) g.summary,
  ];

  @override
  Future<TrailGroup> saveGroup(String id, GroupDraft draft) async {
    _online();
    saved[id] = draft;
    return groups[id] = TrailGroup(
      summary: TrailGroupSummary(
        id: id,
        kind: draft.kind,
        name: draft.name,
        metres: 0,
        trailCount: draft.members.length,
        source: walkerSource,
        mine: true,
      ),
      description: draft.description,
      members: [
        for (final m in draft.members)
          TrailGroupMember(
            m.role ?? MemberRole.main,
            trail: m.trailId == null ? null : sharedTrail(m.trailId!),
          ),
      ],
    );
  }

  @override
  Future<void> removeGroup(String id) async => groups.remove(id);

  @override
  Future<TrailReviews> reviews(String id) async {
    _online();
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
    _online();
    if (placeFailure case final status?) {
      throw RemoteFailure(status, const AppMessage('placeTooFar'));
    }
  }

  @override
  Future<TrailPlacePage> places(int since) async {
    _online();
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
    Library library() => Library(
      SqliteTrailRepository(db),
      XmlGpxDecoder(),
      Elevation(),
      identity: identity,
    );

    test(
      'the same line imported again, even renamed, is not duplicated',
      () async {
        final first = await library().import(gpx('Crête', ridge), 'a.gpx');
        final fingerprint = identity.fingerprint(first.trails.single.segments)!;
        expect(first.reused, 0);
        expect(first.trails.single.id, identity.sharedId(fingerprint));
        final again = await library().import(
          gpx('Crête renommée 🥾', ridge),
          'b.gpx',
        );
        expect(again.reused, 1);
        expect(again.trails.single.id, first.trails.single.id);
        expect(await SqliteTrailRepository(db).all(), hasLength(1));
      },
    );
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
      expect(await upgraded.getVersion(), 5);
      final restored = (await SqliteTrailRepository(upgraded).all()).single;
      expect(restored.name, 'Été à Chamonix 🏔️');
      expect(restored.publicId, isNull);
      expect(await SqliteSyncStore(upgraded).next(), isNotNull);
      expect(
        (await SqliteTrailStatisticsStore(upgraded).find('kept'))!.walks,
        2,
      );
      expect(await SqliteSharedTrailStore(upgraded).details('kept'), isNull);
      await upgraded.close();
    });

    test('upgrading a version 3 database drops the cached catalogue only', () async {
      final path = '${dir.path}/v3.sqlite';
      final v3 = await openDatabase(
        path,
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE trails (id TEXT PRIMARY KEY, payload TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0, mutation TEXT NOT NULL, public_id TEXT)',
          );
          await db.execute(
            'CREATE TABLE outbox (sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, operation TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, deleted INTEGER NOT NULL, base INTEGER, blocked INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE trail_statistics (trail_id TEXT PRIMARY KEY, walks INTEGER NOT NULL, metres REAL NOT NULL, seconds INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE shared_trails (id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, change INTEGER NOT NULL, summary TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE trail_reviews (trail_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE trail_places (id TEXT PRIMARY KEY, trail_id TEXT NOT NULL, change INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL, pending TEXT, version INTEGER NOT NULL DEFAULT 0)',
          );
        },
      );
      await v3.insert('shared_trails', {
        'id': 'cached',
        'fingerprint': 'f',
        'change': 1,
        'summary': '{}',
      });
      await v3.insert('settings', {
        'key': 'shared-trails-cursor',
        'value': '1',
      });
      await v3.insert('settings', {'key': 'trail-places-cursor', 'value': '4'});
      // A shared trail opened before: kept on the phone, never changed.
      final opened = Trail(
        id: 'opened',
        name: 'Ouvert avant',
        segments: [
          [for (final p in ridge) GeoPoint(p.$1, p.$2)],
        ],
        pois: const [],
      ).withPublicId('opened');
      await SqliteTrailRepository(v3).keep(opened);
      await v3.close();
      final upgraded = await openLocalDatabase(path);
      expect(await upgraded.getVersion(), 5);
      final tables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(tables.map((t) => t['name']), isNot(contains('shared_trails')));
      expect(tables.map((t) => t['name']), contains('catalogue_details'));
      final settings = await upgraded.query('settings');
      expect(settings.map((s) => s['key']), ['trail-places-cursor']);
      expect(await SqliteSharedTrailStore(upgraded).placeCursor(), 4);
      expect(await SqliteTrailRepository(upgraded).offlineCopies(), {
        'opened',
      }, reason: 'trails opened before stay available offline');
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
      expect(
        await repository.offlineCopies(),
        isEmpty,
        reason: 'the walker\'s own trails are not offline copies',
      );
    });

    test('a trail kept offline stays local until changed', () async {
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
      expect(await repository.offlineCopies(), {'shared'});
      await repository.keep(trail.withDays(const []));
      expect(await repository.all(), hasLength(1));
      await repository.delete('shared');
      expect(await repository.all(), isEmpty);
      expect(await store.next(), isNull, reason: 'never in the account');
      await repository.save(trail);
      expect(await repository.offlineCopies(), isEmpty, reason: 'changed');
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

    test('details of an offline trail survive restarts', () async {
      final store = SqliteSharedTrailStore(db);
      await store.keepDetails('public', publicDetails);
      final read = (await store.details('public'))!;
      expect(read.description('fr', ''), 'Première étape vers Compostelle');
      expect(read.ref, 'GR 65');
      expect(read.osmId, 300);
      expect(read.paths.single.groups.map((g) => g.id), [
        'st-james',
        'podiensis',
      ]);
      expect(read.paths.single.stage, 1);
      expect(read.paths.single.groups.first.editorial, 'st-james');
      await store.forgetDetails('public');
      expect(await store.details('public'), isNull);
    });
  });

  group('catalogue JSON', () {
    test('area, search pages and groups decode the API shapes', () {
      final area = CatalogueCodec.area({
        'trails': [
          {
            'id': 'a',
            'name': 'GR 20 Nord-Sud',
            'author': null,
            'metres': 180000.5,
            'bounds': [41.5, 8.9, 42.6, 9.4],
            'outline': [
              [
                [41.5, 9.0],
                [42.6, 9.3],
              ],
            ],
            'reviews': 0,
            'average': null,
            'source': 'osm',
            'ref': 'GR 20',
            'change': 7,
          },
        ],
        'truncated': true,
      });
      expect(area.truncated, isTrue);
      expect(area.trails.single.openData, isTrue);
      expect(area.trails.single.bounds!.north, 42.6);
      expect(area.trails.single.outline.single, hasLength(2));
      final page = CatalogueCodec.page({
        'items': [
          {
            'type': 'group',
            'group': {
              'id': 'g',
              'kind': 'itinerary',
              'name': 'GR 20',
              'editorial': null,
              'ref': 'GR 20',
              'metres': 180000,
              'trailCount': 2,
              'bounds': null,
              'source': 'osm',
              'author': null,
              'mine': false,
            },
          },
          {
            'type': 'trail',
            'trail': {'id': 't', 'name': 'Variante', 'metres': 9000},
          },
          {'type': 'newer-kind'},
        ],
        'next': '30',
      });
      expect(page.next, '30');
      expect(page.items, hasLength(2), reason: 'unknown kinds are skipped');
      expect(
        (page.items.first as CatalogueGroupItem).group.kind,
        TrailGroupKind.itinerary,
      );
      final group = CatalogueCodec.fullGroup({
        'id': 'g',
        'kind': 'itinerary',
        'name': 'GR 20',
        'metres': 180000,
        'trailCount': 2,
        'source': 'osm',
        'description': '',
        'details': {'ref': 'GR 20', 'marking': 'red:white:red_bar'},
        'members': [
          {
            'role': 'main',
            'stage': null,
            'type': 'trail',
            'trail': {'id': 'm', 'name': 'Principal', 'metres': 170000},
          },
          {
            'role': 'variant',
            'stage': null,
            'type': 'trail',
            'trail': {'id': 'v', 'name': 'Variante', 'metres': 9000},
          },
        ],
        'parents': [],
      });
      expect(group.members.map((m) => m.role), [
        MemberRole.main,
        MemberRole.variant,
      ]);
      expect(group.details.marking, 'red:white:red_bar');
      expect(group.trails.map((t) => t.id), ['m', 'v']);
    });

    test('a walker\'s group is sent with its members in order', () {
      final json = CatalogueCodec.encodeDraft(
        const GroupDraft(
          kind: TrailGroupKind.collection,
          name: 'Été ☀️',
          members: [
            GroupMemberRef(trailId: 't1'),
            GroupMemberRef(groupId: 'g1', role: MemberRole.main),
          ],
        ),
      );
      expect(json['kind'], 'collection');
      expect(json['members'], [
        {'trailId': 't1'},
        {'groupId': 'g1', 'role': 'main'},
      ]);
    });
  });

  test(
    'syncing sends and receives places without copying the catalogue',
    () async {
      final transport = FakeTransport()..areaTrails = [sharedTrail('public')];
      final sync = SynchronizeLibrary(
        SqliteSyncStore(db),
        _NoSync(),
        shared: (transport: transport, store: SqliteSharedTrailStore(db)),
      );
      await sync.refreshShared();
      expect(transport.requestedAreas, isEmpty);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='shared_trails'",
      );
      expect(tables, isEmpty);
    },
  );

  group('map and reviews', () {
    late FakeTransport transport;
    late AppController app;
    late Trail full;
    late SqliteTrailRepository repository;
    const view = Bounds(6.1, 45.1, 6.3, 45.3);
    setUp(() async {
      transport = FakeTransport();
      final shared = SqliteSharedTrailStore(db);
      repository = SqliteTrailRepository(db);
      full = Trail(
        id: 'public',
        name: 'Crête partagée',
        segments: [
          [for (final p in ridge) GeoPoint(p.$1, p.$2, 800)],
        ],
        pois: const [],
      );
      transport.full['public'] = full;
      transport.areaTrails = [
        sharedTrail('public', reviews: 3, average: 4.3),
        sharedTrail('mine-public', name: 'Duplicate of mine'),
      ];
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
          catalogue: transport,
        ),
      );
      await app.reload();
      await app.browseArea(view);
    });
    tearDown(() => app.dispose());

    test('the visible area pins catalogue trails beside the library', () {
      expect(transport.requestedAreas.single.north, 45.3);
      expect(app.pinned.map((t) => t.id), ['mine', 'public']);
      expect(app.isPreview(app.pinned.last), isTrue);
      expect(app.stored(app.pinned.first), isTrue, reason: 'own colour');
      expect(app.stored(app.pinned.last), isFalse, reason: 'catalogue colour');
      expect(app.sharedFor(app.pinned.first)!.name, 'Duplicate of mine');
    });

    test('offline, the last area stays and the library is kept', () async {
      transport.online = false;
      await app.browseArea(const Bounds(0, 0, 1, 1));
      expect(app.pinned.map((t) => t.id), ['mine', 'public']);
    });

    test(
      'opening a catalogue trail keeps it in memory, not on the phone',
      () async {
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
        expect(app.stored(app.focused!), isFalse);
        expect((await repository.all()).map((t) => t.id), ['mine']);
        expect(app.details!.ref, 'GR 65');
        await app.refreshReviews();
        expect(app.reviews!.completion, .42);
        await app.reload();
        expect(app.focused!.id, 'public', reason: 'still open after reload');
      },
    );

    test('a trail made available offline is kept with its details', () async {
      await app.open(app.pinned.last);
      await app.makeAvailableOffline(app.focused!);
      expect(app.message, AppMessage.availableOffline);
      expect(app.stored(app.focused!), isTrue);
      expect(app.isOfflineCopy(app.focused!), isTrue);
      expect(app.pinned.where((t) => t.id == 'public'), hasLength(1));
      expect((await SqliteSharedTrailStore(db).details('public'))!.osmId, 300);
      transport.online = false;
      await app.reload();
      app.focus(app.trails.firstWhere((t) => t.id == 'public'));
      await app.refreshDetails();
      expect(app.details!.ref, 'GR 65', reason: 'details read offline');
      await app.removeOffline(app.focused!);
      expect(app.message, AppMessage.offlineRemoved);
      expect((await repository.all()).map((t) => t.id), ['mine']);
      expect(await SqliteSharedTrailStore(db).details('public'), isNull);
      expect(app.focused!.id, 'public', reason: 'open until closed');
    });

    test(
      'starting a catalogue trail makes it available offline first',
      () async {
        await app.open(app.pinned.last);
        await app.launch(app.focused!);
        expect(app.isOfflineCopy(app.focused!), isTrue);
        expect(app.selected!.id, 'public');
        expect(
          (await repository.all()).map((t) => t.id),
          containsAll(['mine', 'public']),
        );
      },
    );

    test('offline, an unopened catalogue trail reports it honestly', () async {
      transport.online = false;
      await app.open(app.pinned.last);
      expect(app.focused, isNull);
      expect(
        (app.message as MessageFailure).detail.code,
        'sharedTrailUnavailable',
      );
    });

    test('search results and groups come from the server', () async {
      final page = await app.searchCatalogue('Compostelle');
      expect(page.items.first, isA<CatalogueGroupItem>());
      app.noteSearchResults(page);
      await app.openShared('public');
      expect(app.focused!.id, 'public');
      await app.openShared('mine-public');
      expect(app.focused!.id, 'mine', reason: 'own copy opens first');
    });

    test(
      'a walker creates a group and adds trails to it after syncing',
      () async {
        final created = await app.createGroup(
          const GroupDraft(
            kind: TrailGroupKind.itinerary,
            name: '  Mon GR 65 ',
            members: [GroupMemberRef(trailId: 'public')],
          ),
        );
        expect(app.message, AppMessage.groupSaved);
        expect(created!.summary.name, 'Mon GR 65');
        await app.addToGroup(created.summary, app.trails.single);
        expect((app.message as AppMessage).code, 'addedToGroup');
        expect((app.message as AppMessage).arguments, ['Mon GR 65']);
        expect(
          transport.saved[created.summary.id]!.members.map((m) => m.trailId),
          ['public', 'mine-public'],
        );
        await app.createGroup(
          const GroupDraft(kind: TrailGroupKind.collection, name: '  '),
        );
        expect((app.message as MessageFailure).detail.code, 'invalidGroup');
        expect(await app.removeGroup(created.summary.id), isTrue);
        expect(transport.groups, isEmpty);
      },
    );

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
        app.closeTrail();
        expect(app.visiblePlaces, isEmpty, reason: 'shown with its trail');
        app.focus(app.trails.firstWhere((t) => t.id == 'mine'));
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

    Widget page(String language, Widget child) => MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ListView(children: [child])),
    );

    for (final (language, write, required) in [
      ('en', 'Give my review', 'in one go or over several walks'),
      ('fr', 'Donner mon avis', 'en une ou plusieurs fois'),
    ]) {
      testWidgets('the panel shows reviews and who may write ($language)', (
        tester,
      ) async {
        Future<void> show(TrailReviews reviews) async {
          app.reviews = reviews;
          await tester.pumpWidget(
            page(language, TrailReviewsSection(app, full)),
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

    for (final (language, description, stage, attribution, st) in [
      (
        'en',
        'First stage to Santiago',
        'Stage 1 of',
        'Trail data © OpenStreetMap contributors, ODbL licence',
        'Ways of St James (Camino de Santiago)',
      ),
      (
        'fr',
        'Première étape vers Compostelle',
        'Étape 1 de',
        'Données du parcours © contributeurs OpenStreetMap, licence ODbL',
        'Chemins de Saint-Jacques-de-Compostelle',
      ),
    ]) {
      testWidgets(
        'the panel shows where a trail belongs and its source ($language)',
        (tester) async {
          app.details = publicDetails;
          await tester.pumpWidget(
            page(language, TrailDetailsSection(app, full)),
          );
          await tester.pumpAndSettle();
          expect(find.text(description), findsOneWidget);
          expect(find.text(stage), findsOneWidget);
          expect(
            find.text(st),
            findsOneWidget,
            reason: 'translated collection',
          );
          expect(find.text('Via Podiensis'), findsOneWidget, reason: 'source');
          expect(find.text('GR 65'), findsOneWidget);
          expect(find.byType(MarkingBadge), findsOneWidget);
          expect(find.text(attribution), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );
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
