import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/data/photon_place_search.dart';
import 'package:gpix/domain/models.dart';
import 'package:gpix/domain/trail_geometry.dart';
import 'package:gpix/presentation/app.dart';
import 'package:gpix/presentation/design.dart';
import 'package:gpix/presentation/localization.dart';
import 'package:gpix/presentation/trail_pins.dart';

import 'lifecycle_test.dart' as fixtures;

Trail line(String id, List<List<GeoPoint>> segments) =>
    Trail(id: id, name: id, segments: segments, pois: []);

void main() {
  group('visible centre', () {
    final trail = line('east', [
      [const GeoPoint(0, 0), const GeoPoint(0, 1), const GeoPoint(0, 2)],
    ]);
    test('a fully visible trail is pinned at its middle, not its start', () {
      final centre = TrailGeometry(trail)
          .visibleCentre(const Bounds(-1, -1, 3, 1))!;
      expect(centre.lat, closeTo(0, 1e-9));
      expect(centre.lon, closeTo(1, 1e-6));
    });
    test('a partly visible trail is pinned inside the visible part', () {
      final centre = TrailGeometry(trail)
          .visibleCentre(const Bounds(1.4, -1, 1.8, 1))!;
      expect(centre.lon, closeTo(1.6, 1e-6));
    });
    test('an edge crossing the view without any visible vertex counts', () {
      final centre = TrailGeometry(trail)
          .visibleCentre(const Bounds(.2, -.1, .4, .1))!;
      expect(centre.lon, closeTo(.3, 1e-6));
    });
    test('an off-screen trail has no pin', () {
      expect(
        TrailGeometry(trail).visibleCentre(const Bounds(5, 5, 6, 6)),
        isNull,
      );
    });
    test('segment gaps never join two visible portions', () {
      final gapped = line('gap', [
        [const GeoPoint(0, 0), const GeoPoint(0, .3)],
        [const GeoPoint(0, .5), const GeoPoint(0, 1.5)],
      ]);
      final centre = TrailGeometry(gapped)
          .visibleCentre(const Bounds(0, -1, 1, 1))!;
      // The longest visible portion is .5 → 1 on the second segment.
      expect(centre.lon, closeTo(.75, 1e-6));
    });
  });

  test('a pin stays put while on screen and moves once it leaves it', () {
    final trail = line('east', [
      [const GeoPoint(0, 0), const GeoPoint(0, 2)],
    ]);
    final first = stickyAnchors([], [trail], const Bounds(-1, -1, 3, 1));
    expect(first.single.$2.lon, closeTo(1, 1e-6));
    // Panned east: the pin is still visible, so it does not jump.
    final panned = stickyAnchors(first, [trail], const Bounds(.5, -1, 4, 1));
    expect(panned.single.$2.lon, closeTo(1, 1e-6));
    // Panned further: the old pin left the view, a new one is placed.
    final moved = stickyAnchors(panned, [trail], const Bounds(1.5, -1, 4, 1));
    expect(moved.single.$2.lon, closeTo(1.75, 1e-6));
    // A deleted trail loses its pin.
    expect(stickyAnchors(moved, [], const Bounds(1.5, -1, 4, 1)), isEmpty);
  });

  test('own and catalogue pins go to separate clustered sources', () {
    final own = line('own', []), public = line('public', []);
    final anchors = [
      (own, const GeoPoint(45, 6)),
      (public, const GeoPoint(45.001, 6.001)),
    ];
    Map<String, dynamic> kind(bool catalogue) => pinFeatures(
      anchors,
      catalogue: catalogue,
      isCatalogue: (t) => t.id == 'public',
    );
    final features = kind(false)['features'] as List;
    expect(features.single['properties'], {'trail': 'own'});
    expect(features.single['geometry']['coordinates'], [6, 45]);
    expect((kind(true)['features'] as List).single['id'], 'public');
  });

  test('trail search ignores case and French accents', () {
    expect(foldForSearch('Étang de Berre'), 'etang de berre');
    expect(foldForSearch('Cœur'), 'coeur');
    expect(foldForSearch('Col 🏔'), 'col 🏔');
  });

  group('Photon place search', () {
    const body = '''{"features":[
      {"geometry":{"coordinates":[1.4442,43.6045]},
       "properties":{"name":"Toulouse","state":"Occitanie","country":"France",
         "extent":[1.35,43.67,1.52,43.53]}},
      {"geometry":{"coordinates":[2.35,48.85]},
       "properties":{"housenumber":"8","street":"Rue de l’Été","city":"Paris","postcode":"75001"}},
      {"geometry":{"coordinates":[500,500]},"properties":{"name":"Broken"}}
    ]}''';
    test(
      'decodes names, details and ordered extents without altering text',
      () {
        final places = decodePhoton(body);
        expect(places.length, 2);
        expect(places.first.name, 'Toulouse');
        expect(places.first.detail, 'Occitanie, France');
        expect(places.first.extent!.south, 43.53);
        expect(places.first.extent!.north, 43.67);
        expect(places.last.name, '8 Rue de l’Été');
        expect(places.last.detail, '75001, Paris');
      },
    );
    test(
      'sends language and position, and reports failures as messages',
      () async {
        Uri? sent;
        final search = PhotonPlaceSearch(
          MockClient((request) async {
            sent = request.url;
            return http.Response.bytes(utf8.encode(body), 200);
          }),
          base: 'https://geo.example.org/photon/',
          languageCode: () => 'fr',
        );
        final places = await search.search(
          'Toulouse',
          near: const GeoPoint(43.6, 1.44),
        );
        expect(places.first.name, 'Toulouse');
        expect(sent!.path, '/photon/api/');
        expect(sent!.queryParameters['lang'], 'fr');
        expect(sent!.queryParameters['lat'], '43.6000');
        final offline = PhotonPlaceSearch(
          MockClient((_) async => throw http.ClientException('offline')),
        );
        await expectLater(
          offline.search('Toulouse'),
          throwsA(
            isA<MessageFailure>().having(
              (e) => e.detail.code,
              'code',
              AppMessage.placeSearchUnavailable.code,
            ),
          ),
        );
      },
    );
  });

  for (final (language, distance, ascent) in [
    ('en', 'distance', 'ascent'),
    ('fr', 'distance', 'dénivelé +'),
  ]) {
    testWidgets('an open trail shows its length and climb ($language)', (
      tester,
    ) async {
      final app = fixtures.controller();
      final trail = Trail(
        id: 'climb',
        name: 'Montée',
        segments: [
          [
            const GeoPoint(45, 6, 1000),
            const GeoPoint(45.009, 6, 1080),
            const GeoPoint(45.018, 6, 1060),
          ],
        ],
        pois: const [],
      );
      await app.library.repository.save(trail);
      await app.reload();
      app.focus(trail);
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
      expect(find.text(distance), findsOneWidget);
      expect(find.text(ascent), findsOneWidget);
      expect(find.text('80 m'), findsOneWidget, reason: 'only the climb');
      expect(find.text(language == 'fr' ? '2,0 km' : '2.0 km'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }

  testWidgets('the menu opens every page over the map and back returns to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = fixtures.controller();
    await tester.pumpWidget(
      GpixApp(app, mapBuilder: (_) => const ColoredBox(color: Colors.green)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Search a town, an address…'), findsOneWidget);
    expect(find.text('Import a trail'), findsOneWidget);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No map installed'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to the map'));
    await tester.pumpAndSettle();
    expect(find.text('Search a town, an address…'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('the trail list filters by name in French', (tester) async {
    final app = fixtures.controller();
    for (final name in ['Étang de Thau', 'Mont Aigoual']) {
      await app.library.repository.save(
        line(name, [
          [const GeoPoint(43, 3), const GeoPoint(43.01, 3.01)],
        ]),
      );
    }
    await app.reload();
    final locale = LocaleController(initialLocale: const Locale('fr'));
    await tester.pumpWidget(
      LocalizedApp(
        controller: locale,
        homeBuilder: (_) =>
            Home(app, mapBuilder: (_) => const ColoredBox(color: Colors.green)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes parcours'));
    await tester.pumpAndSettle();
    expect(find.text('Mont Aigoual'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'etang');
    await tester.pumpAndSettle();
    expect(find.text('Étang de Thau'), findsOneWidget);
    expect(find.text('Mont Aigoual'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Canigou');
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun parcours ne correspond à « Canigou ».'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    locale.dispose();
  });
}
