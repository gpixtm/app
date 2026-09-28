import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/backend_environment.dart';
import 'package:gpix/application/collaborative_trails.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/application/synchronize_library.dart';
import 'package:gpix/data/local_database.dart';
import 'package:gpix/data/server_connection.dart';
import 'package:gpix/data/shared_trail_api.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/data/trail_identity_hash.dart';
import 'package:gpix/domain/app_message.dart';
import 'package:gpix/domain/catalogue.dart';
import 'package:gpix/domain/connection_settings.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/walk_recording.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'lifecycle_test.dart' show Elevation;

class _Credentials implements CredentialStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Test-only transport: the declared emulator origin is forwarded to this
/// computer's loopback, where a disposable API listens.
class _Loopback extends http.BaseClient {
  final _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != 'http://10.0.2.2:8080') {
      throw StateError('Only the fixed emulator origin is forwarded.');
    }
    return _inner.send(
      http.Request(request.method, request.url.replace(host: '127.0.0.1'))
        ..followRedirects = false
        ..headers.addAll(request.headers)
        ..bodyBytes = await request.finalize().toBytes(),
    );
  }

  @override
  void close() => _inner.close();
}

/// One walker's phone: its own SQLite library and account session.
class _Phone {
  _Phone(this.db, this.server)
    : repository = SqliteTrailRepository(db),
      shared = SqliteSharedTrailStore(db) {
    transport = ApiSharedTrailTransport(server.bindAccount());
    library = Library(
      repository,
      XmlGpxDecoder(),
      Elevation(),
      identity: const HashedTrailIdentity(),
    );
    sync = SynchronizeLibrary(
      SqliteSyncStore(db),
      ApiSyncTransport(server.bindAccount()),
      shared: (transport: transport, store: shared),
    );
    trails = CollaborativeTrails(
      shared,
      transport,
      repository,
      newId: const Uuid().v4,
      catalogue: transport,
    );
  }
  final Database db;
  final ServerConnection server;
  final SqliteTrailRepository repository;
  final SqliteSharedTrailStore shared;
  late final ApiSharedTrailTransport transport;
  late final Library library;
  late final SynchronizeLibrary sync;
  late final CollaborativeTrails trails;
}

void main() {
  final enabled = Platform.environment['GPIX_TEST_SHARED_API'] == '1';
  test(
    'two walkers on a real API share one trail and review it after walking it',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('gpix-shared-api');
      final client = _Loopback();
      final phones = <_Phone>[];
      try {
        final tag = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
        for (final name in ['a', 'b']) {
          final server = ServerConnection(
            client,
            environment: BackendEnvironment(
              BackendMode.dev,
              'http://10.0.2.2:8080',
            ),
            credentials: _Credentials(),
          );
          await server.register(
            'it_${name}_$tag',
            'it_${name}_$tag@example.invalid',
            'Integration-$tag',
          );
          phones.add(
            _Phone(await openLocalDatabase('${dir.path}/$name.db'), server),
          );
        }
        final [a, b] = phones;
        // A line unique to this run, so the shared catalogue has no copy yet.
        final origin = 44 + (DateTime.now().millisecond / 10000);
        String gpx(String name) =>
            '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>$name</name><trkseg>
${[for (var i = 0; i < 12; i++) '<trkpt lat="${origin + i * .0009}" lon="5.5"><ele>${700 + i}</ele></trkpt>'].join()}
</trkseg></trk></gpx>''';

        final added = await a.library.import(gpx('Sentier des crêtes 🥾'), 'a');
        final id = added.trails.single.id;
        await a.sync.synchronize();
        expect((await a.repository.all()).single.publicId, id);

        // The other walker finds it on the server, by area and by name.
        final area = await b.trails.area(
          Bounds(5.49, origin - .001, 5.51, origin + .011),
        );
        final listed = area.trails.singleWhere((t) => t.id == id);
        expect(listed.name, 'Sentier des crêtes 🥾');
        expect(listed.author, startsWith('it_a_'));
        final found = await b.trails.search('Sentier des crêtes');
        expect(
          found.items.whereType<CatalogueTrailItem>().map((i) => i.trail.id),
          contains(id),
        );

        final copy = await b.library.import(gpx('Renamed export'), 'b');
        expect(copy.trails.single.id, id, reason: 'same line, same trail');
        await b.sync.synchronize();
        expect((await b.repository.all()).single.publicId, id);

        final downloaded = (await b.trails.open(id)).trail;
        expect(downloaded.segments.single, hasLength(12));

        await expectLater(
          b.trails.review(id, 5, 'Magnifique'),
          throwsA(
            isA<ApiFailure>().having(
              (e) => (e.message as AppMessage).code,
              'code',
              'completionRequired',
            ),
          ),
        );
        expect((await b.trails.reviews(id)).canReview, isFalse);

        final started = DateTime.utc(2026, 9, 27, 8);
        await b.repository.save(
          Trail(
            id: const Uuid().v4(),
            name: 'Walk',
            segments: [downloaded.segments.single.reversed.toList()],
            pois: const [],
            walk: WalkDetails(
              started: started,
              ended: started.add(const Duration(hours: 1)),
              seconds: 3400,
              sourceTrailId: id,
              samples: const [],
            ),
          ),
        );
        await b.sync.synchronize();
        final reviewed = await b.trails.review(id, 5, ' Magnifique 🌄 ');
        expect(reviewed.canReview, isTrue);
        expect(reviewed.mine!.comment, 'Magnifique 🌄');

        final rated = (await a.trails.open(id)).details;
        expect(rated.reviews, 1);
        expect(rated.average, 5);
        // A place added on the trail reaches the other walker.
        final line = (await a.repository.all()).single;
        await b.trails.addPlace(
          line,
          GeoPoint(origin + .0045, 5.5003, 1234),
          'Belle vue 🏔️',
          'Au lever du soleil',
        );
        await b.sync.synchronize();
        expect(await b.shared.pendingPlaces(), isEmpty);
        await a.sync.synchronize();
        final place = (await a.shared.places()).single;
        expect(place.name, 'Belle vue 🏔️');
        expect(place.trailId, id);
        expect(place.author, startsWith('it_b_'));
        expect(place.mine, isFalse);

        final seen = await a.trails.reviews(id);
        expect(seen.reviews.single.author, startsWith('it_b_'));
        expect(seen.reviews.single.mine, isFalse);
      } finally {
        for (final phone in phones) {
          await phone.db.close();
        }
        client.close();
        await dir.delete(recursive: true);
      }
    },
    skip: enabled
        ? false
        : 'Set GPIX_TEST_SHARED_API=1 with a disposable API at 127.0.0.1:8080',
  );
}
